import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/protocol.dart';
import '../models/protocol_publication.dart';
import '../models/published_protocol_manifest.dart';
import '../models/published_protocol_package.dart';
import 'auth_service.dart';

typedef PublicationHeadersProvider =
    Future<Map<String, String>?> Function(bool promptIfNecessary);

class PublicationException implements Exception {
  const PublicationException(this.message, {this.sharingBlocked = false});

  final String message;
  final bool sharingBlocked;

  @override
  String toString() => message;
}

class SharedProtocolLink {
  const SharedProtocolLink({
    required this.fileId,
    this.resourceKey,
    this.version,
  });

  final String fileId;
  final String? resourceKey;
  final int? version;

  static SharedProtocolLink? tryParse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    var fileId = uri.queryParameters['import'] ?? uri.queryParameters['id'];
    if ((fileId == null || fileId.isEmpty) && uri.pathSegments.length >= 3) {
      final fileIndex = uri.pathSegments.indexOf('d');
      if (fileIndex >= 0 && fileIndex + 1 < uri.pathSegments.length) {
        fileId = uri.pathSegments[fileIndex + 1];
      }
    }
    if (fileId == null || fileId.trim().isEmpty) return null;
    return SharedProtocolLink(
      fileId: fileId.trim(),
      resourceKey:
          uri.queryParameters['resourceKey'] ??
          uri.queryParameters['resourcekey'],
      version: int.tryParse(uri.queryParameters['version'] ?? ''),
    );
  }
}

class SharedProtocolDownload {
  const SharedProtocolDownload({
    required this.manifest,
    required this.package,
    required this.isLegacyPublication,
  });

  final PublishedProtocolManifest manifest;
  final PublishedProtocolPackage package;
  final bool isLegacyPublication;
}

class _OwnerPublicationRoot {
  const _OwnerPublicationRoot({this.manifest, this.legacyPackage});

  final PublishedProtocolManifest? manifest;
  final PublishedProtocolPackage? legacyPackage;

  String get publicationId =>
      manifest?.publicationId ?? legacyPackage!.publicationId;
  int get latestVersion => manifest?.latestVersion ?? legacyPackage!.version;
}

class _GrantedPermission {
  const _GrantedPermission({required this.fileId, required this.permissionId});

  final String fileId;
  final String permissionId;
}

class ProtocolPublicationService {
  ProtocolPublicationService({
    http.Client? client,
    PublicationHeadersProvider? headersProvider,
  }) : _client = client ?? http.Client(),
       _headersProvider =
           headersProvider ??
           ((prompt) => AuthService.instance.authorizationHeadersForPublishing(
             promptIfNecessary: prompt,
           ));

  static final ProtocolPublicationService instance =
      ProtocolPublicationService();

  static const String _baseUrl = 'https://www.googleapis.com/drive/v3';
  static const String _uploadBaseUrl =
      'https://www.googleapis.com/upload/drive/v3';
  static const int _maxPackageBytes = 5 * 1024 * 1024;

  final http.Client _client;
  final PublicationHeadersProvider _headersProvider;

  Future<ProtocolPublication> publish({
    required Protocol protocol,
    required String ownerGoogleUserId,
    required String? authorName,
    required bool anonymous,
  }) async {
    if (protocol.isTemplate) {
      throw const PublicationException(
        'Save this template as a protocol before publishing it.',
      );
    }
    if (protocol.title.trim().isEmpty) {
      throw const PublicationException('The protocol needs a title.');
    }
    final current = protocol.publication;
    if (current != null &&
        current.ownerGoogleUserId.isNotEmpty &&
        current.ownerGoogleUserId != ownerGoogleUserId) {
      throw const PublicationException(
        'Only the Google account that published this protocol can update it.',
      );
    }
    final headers = await _requireHeaders(promptIfNecessary: true);
    final publicationId = current?.publicationId ?? _newPublicationId();
    final folderId = await _sharedProtocolsFolder(headers);
    final existingRoot = current != null && current.driveFileId.isNotEmpty
        ? await _loadOwnerPublicationRoot(
            fileId: current.driveFileId,
            resourceKey: current.resourceKey,
            headers: headers,
          )
        : null;
    if (existingRoot != null && existingRoot.publicationId != publicationId) {
      throw const PublicationException(
        'The published protocol identity does not match this local protocol.',
      );
    }
    final previousVersion =
        existingRoot?.latestVersion ?? current?.version ?? 0;
    final version = previousVersion + 1;
    final publishedAt = DateTime.now().toUtc();
    final publicAuthor = anonymous ? null : authorName?.trim();
    final package = PublishedProtocolPackage.create(
      source: protocol,
      publicationId: publicationId,
      version: version,
      publishedAt: publishedAt,
      authorName: (publicAuthor?.isEmpty ?? true) ? null : publicAuthor,
    );
    final createdFileIds = <String>[];
    final restoredPublicPermissions = <_GrantedPermission>[];
    String? rootFileId = existingRoot == null ? null : current?.driveFileId;
    String? permissionId = current?.permissionId;
    try {
      if (rootFileId != null) {
        permissionId = await _ensureAnyoneReader(
          rootFileId,
          headers,
          trackNewPermission: restoredPublicPermissions,
        );
      }
      var manifest = existingRoot?.manifest;
      if (manifest != null) {
        for (final entry in manifest.versions) {
          await _ensureAnyoneReader(
            entry.fileId,
            headers,
            trackNewPermission: restoredPublicPermissions,
          );
        }
      }
      if (existingRoot?.legacyPackage case final legacy?) {
        final legacyEntry = await _createPublicVersionFile(
          folderId: folderId,
          publicationId: publicationId,
          title: legacy.protocol.title,
          package: legacy,
          headers: headers,
          createdFileIds: createdFileIds,
        );
        manifest = PublishedProtocolManifest(
          publicationId: publicationId,
          title: legacy.protocol.title,
          latestVersion: legacy.version,
          updatedAt: legacy.publishedAt,
          versions: [legacyEntry],
        );
      }
      final versionEntry = await _createPublicVersionFile(
        folderId: folderId,
        publicationId: publicationId,
        title: protocol.title,
        package: package,
        headers: headers,
        createdFileIds: createdFileIds,
      );
      manifest = manifest == null
          ? PublishedProtocolManifest(
              publicationId: publicationId,
              title: protocol.title.trim(),
              latestVersion: version,
              updatedAt: publishedAt,
              versions: [versionEntry],
            )
          : manifest.append(title: protocol.title.trim(), entry: versionEntry);
      final manifestContent = const JsonEncoder.withIndent(
        '  ',
      ).convert(manifest.toJson());
      if (rootFileId != null) {
        final updated = await _updatePublishedFile(
          fileId: rootFileId,
          fileName: _publishedFileName(protocol.title),
          content: manifestContent,
          headers: headers,
        );
        if (!updated) rootFileId = null;
      }
      if (rootFileId == null) {
        rootFileId = await _createPublishedFile(
          folderId: folderId,
          fileName: _publishedFileName(protocol.title),
          content: manifestContent,
          headers: headers,
          appProperties: {
            'protocolflowPublishedManifest': 'true',
            'protocolflowPublicationId': publicationId,
          },
        );
        createdFileIds.add(rootFileId);
        permissionId = await _ensureAnyoneReader(rootFileId, headers);
      }
    } catch (_) {
      for (final fileId in createdFileIds.reversed) {
        await _bestEffortDelete(fileId, headers);
      }
      for (final permission in restoredPublicPermissions.reversed) {
        await _bestEffortRemovePermission(permission, headers);
      }
      rethrow;
    }
    final metadata = await _loadFileMetadata(rootFileId, headers);
    final resourceKey = metadata['resourceKey']?.toString();
    final shareUri = buildShareUri(rootFileId, resourceKey: resourceKey);
    return ProtocolPublication(
      publicationId: publicationId,
      driveFileId: rootFileId,
      permissionId: permissionId,
      resourceKey: resourceKey,
      version: version,
      publishedAt: publishedAt,
      shareUri: shareUri,
      contentHash: package.contentHash,
      ownerGoogleUserId: ownerGoogleUserId,
      authorName: package.authorName,
      anonymous: anonymous,
      status: ProtocolPublicationStatus.published,
    );
  }

  Future<ProtocolPublication> unpublish(ProtocolPublication publication) async {
    final headers = await _requireOwnerHeaders(publication);
    final root = await _loadOwnerPublicationRoot(
      fileId: publication.driveFileId,
      resourceKey: publication.resourceKey,
      headers: headers,
    );
    await _removeAnyoneReader(publication.driveFileId, headers);
    for (final entry in root?.manifest?.versions ?? const []) {
      await _removeAnyoneReader(entry.fileId, headers);
    }
    return publication.copyWith(status: ProtocolPublicationStatus.unpublished);
  }

  Future<void> deletePublishedCopy(ProtocolPublication publication) async {
    final headers = await _requireOwnerHeaders(publication);
    final root = await _loadOwnerPublicationRoot(
      fileId: publication.driveFileId,
      resourceKey: publication.resourceKey,
      headers: headers,
    );
    final manifest = root?.manifest;
    if (manifest != null) {
      for (final entry in manifest.versions.reversed) {
        await _deleteFile(entry.fileId, headers);
      }
    }
    await _deleteFile(publication.driveFileId, headers);
  }

  Future<PublishedProtocolPackage> downloadSharedProtocol(
    String shareUri,
  ) async => (await downloadSharedPublication(shareUri)).package;

  Future<SharedProtocolDownload> downloadSharedPublication(
    String shareUri, {
    int? version,
  }) async {
    final link = SharedProtocolLink.tryParse(shareUri);
    if (link == null) {
      throw const PublicationException(
        'This is not a valid ProtocolFlow sharing link.',
      );
    }
    final rootJson = await _downloadJsonFile(
      fileId: link.fileId,
      resourceKey: link.resourceKey,
      unavailableMessage:
          'This published protocol is unavailable or its owner revoked access.',
    );
    try {
      if (rootJson['kind'] == PublishedProtocolPackage.kind) {
        final package = PublishedProtocolPackage.fromJson(rootJson);
        final selectedVersion = version ?? link.version;
        if (selectedVersion != null && selectedVersion != package.version) {
          throw const FormatException(
            'The selected published protocol version is unavailable.',
          );
        }
        final manifest = PublishedProtocolManifest(
          publicationId: package.publicationId,
          title: package.protocol.title,
          latestVersion: package.version,
          updatedAt: package.publishedAt,
          versions: [
            PublishedProtocolVersion(
              version: package.version,
              publishedAt: package.publishedAt,
              authorName: package.authorName,
              fileId: link.fileId,
              resourceKey: link.resourceKey,
              contentHash: package.contentHash,
            ),
          ],
        );
        return SharedProtocolDownload(
          manifest: manifest,
          package: package,
          isLegacyPublication: true,
        );
      }
      final manifest = PublishedProtocolManifest.fromJson(rootJson);
      final selectedVersion = version ?? link.version ?? manifest.latestVersion;
      final entry = manifest.version(selectedVersion);
      final packageJson = await _downloadJsonFile(
        fileId: entry.fileId,
        resourceKey: entry.resourceKey,
        unavailableMessage:
            'Published protocol version $selectedVersion is unavailable.',
      );
      final package = PublishedProtocolPackage.fromJson(packageJson);
      if (package.publicationId != manifest.publicationId ||
          package.version != entry.version ||
          package.contentHash != entry.contentHash) {
        throw const FormatException(
          'The published protocol version does not match its manifest.',
        );
      }
      return SharedProtocolDownload(
        manifest: manifest,
        package: package,
        isLegacyPublication: false,
      );
    } on FormatException catch (error) {
      throw PublicationException(error.message);
    } catch (_) {
      throw const PublicationException(
        'The shared protocol file is damaged or unsupported.',
      );
    }
  }

  String buildShareUri(String fileId, {String? resourceKey}) {
    return Uri.https('aviv7001.github.io', '/protocolflow/', {
      'import': fileId,
      if (resourceKey != null && resourceKey.isNotEmpty)
        'resourceKey': resourceKey,
    }).toString();
  }

  Future<Map<String, String>> _requireHeaders({
    required bool promptIfNecessary,
  }) async {
    final headers = await _headersProvider(promptIfNecessary);
    if (headers == null) {
      throw const PublicationException(
        'Google Drive access was not granted. Sign in and try again.',
      );
    }
    return headers;
  }

  Future<Map<String, String>> _requireOwnerHeaders(
    ProtocolPublication publication,
  ) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null ||
        currentUser.googleUserId != publication.ownerGoogleUserId) {
      throw const PublicationException(
        'Sign in with the Google account that published this protocol.',
      );
    }
    return _requireHeaders(promptIfNecessary: true);
  }

  Future<PublishedProtocolVersion> _createPublicVersionFile({
    required String folderId,
    required String publicationId,
    required String title,
    required PublishedProtocolPackage package,
    required Map<String, String> headers,
    required List<String> createdFileIds,
  }) async {
    final fileId = await _createPublishedFile(
      folderId: folderId,
      fileName: _publishedVersionFileName(title, package.version),
      content: const JsonEncoder.withIndent('  ').convert(package.toJson()),
      headers: headers,
      appProperties: {
        'protocolflowPublishedVersion': 'true',
        'protocolflowPublicationId': publicationId,
        'protocolflowVersion': package.version.toString(),
      },
    );
    createdFileIds.add(fileId);
    await _ensureAnyoneReader(fileId, headers);
    final metadata = await _loadFileMetadata(fileId, headers);
    return PublishedProtocolVersion(
      version: package.version,
      publishedAt: package.publishedAt,
      authorName: package.authorName,
      fileId: fileId,
      resourceKey: metadata['resourceKey']?.toString(),
      contentHash: package.contentHash,
    );
  }

  Future<_OwnerPublicationRoot?> _loadOwnerPublicationRoot({
    required String fileId,
    required String? resourceKey,
    required Map<String, String> headers,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/files/$fileId?alt=media'),
      headers: {
        ...headers,
        if (resourceKey != null)
          'X-Goog-Drive-Resource-Keys': '$fileId/$resourceKey',
      },
    );
    if (response.statusCode == 404) return null;
    _throwDriveError(response, operation: 'load the published protocol');
    final json = _decodeJsonResponse(response);
    try {
      if (json['kind'] == PublishedProtocolManifest.kind) {
        return _OwnerPublicationRoot(
          manifest: PublishedProtocolManifest.fromJson(json),
        );
      }
      if (json['kind'] == PublishedProtocolPackage.kind) {
        return _OwnerPublicationRoot(
          legacyPackage: PublishedProtocolPackage.fromJson(json),
        );
      }
      throw const FormatException('Unsupported shared protocol format.');
    } on FormatException catch (error) {
      throw PublicationException(error.message);
    }
  }

  Future<Map<String, dynamic>> _downloadJsonFile({
    required String fileId,
    required String? resourceKey,
    required String unavailableMessage,
  }) async {
    final response = await _client.get(
      Uri.https('drive.usercontent.google.com', '/download', {
        'id': fileId,
        'export': 'download',
        'confirm': 't',
        'resourcekey': ?resourceKey,
      }),
    );
    if (response.statusCode != 200) {
      throw PublicationException(
        response.statusCode == 403 || response.statusCode == 404
            ? unavailableMessage
            : 'The shared protocol could not be downloaded.',
      );
    }
    return _decodeJsonResponse(response);
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    if (response.bodyBytes.length > _maxPackageBytes) {
      throw const PublicationException(
        'The shared protocol file is too large.',
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException();
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const PublicationException(
        'The shared protocol file is damaged or unsupported.',
      );
    }
  }

  Future<void> _removeAnyoneReader(
    String fileId,
    Map<String, String> headers,
  ) async {
    final permissionId = await _findAnyoneReaderPermission(fileId, headers);
    if (permissionId == null || permissionId.isEmpty) return;
    final response = await _client.delete(
      Uri.parse('$_baseUrl/files/$fileId/permissions/$permissionId'),
      headers: headers,
    );
    if (response.statusCode != 204 && response.statusCode != 404) {
      _throwDriveError(response, operation: 'remove public access');
    }
  }

  Future<void> _deleteFile(String fileId, Map<String, String> headers) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/files/$fileId'),
      headers: headers,
    );
    if (response.statusCode != 204 && response.statusCode != 404) {
      _throwDriveError(response, operation: 'delete the published copy');
    }
  }

  Future<String> _sharedProtocolsFolder(Map<String, String> headers) async {
    final root = await _findOrCreateFolder(
      role: 'root',
      name: 'ProtocolFlow',
      headers: headers,
    );
    return _findOrCreateFolder(
      role: 'sharedProtocols',
      name: 'Shared Protocols',
      headers: headers,
      parentId: root,
    );
  }

  Future<String> _findOrCreateFolder({
    required String role,
    required String name,
    required Map<String, String> headers,
    String? parentId,
  }) async {
    final query = Uri.encodeQueryComponent(
      "mimeType = 'application/vnd.google-apps.folder' and trashed = false "
      "and appProperties has { key='protocolflowFolder' and value='$role' }",
    );
    final response = await _client.get(
      Uri.parse(
        '$_baseUrl/files?spaces=drive&q=$query&fields=files(id)&pageSize=10',
      ),
      headers: headers,
    );
    _throwDriveError(response, operation: 'find the publication folder');
    final decoded = jsonDecode(response.body);
    final files = decoded is Map ? decoded['files'] : null;
    if (files is List && files.isNotEmpty && files.first is Map) {
      return (files.first as Map)['id']?.toString() ?? '';
    }
    final createResponse = await _client.post(
      Uri.parse('$_baseUrl/files?fields=id'),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        if (parentId != null) 'parents': [parentId],
        'appProperties': {'protocolflowFolder': role},
      }),
    );
    _throwDriveError(
      createResponse,
      operation: 'create the publication folder',
    );
    return (jsonDecode(createResponse.body) as Map)['id']?.toString() ?? '';
  }

  Future<String> _createPublishedFile({
    required String folderId,
    required String fileName,
    required String content,
    required Map<String, String> headers,
    required Map<String, String> appProperties,
  }) async {
    final boundary =
        'protocolflow_public_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': [folderId],
      'mimeType': 'application/json',
      'appProperties': appProperties,
    });
    final body =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$content\r\n'
        '--$boundary--';
    final response = await _client.post(
      Uri.parse('$_uploadBaseUrl/files?uploadType=multipart&fields=id'),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    _throwDriveError(response, operation: 'upload the published protocol');
    return (jsonDecode(response.body) as Map)['id']?.toString() ?? '';
  }

  Future<bool> _updatePublishedFile({
    required String fileId,
    required String fileName,
    required String content,
    required Map<String, String> headers,
  }) async {
    final mediaResponse = await _client.patch(
      Uri.parse('$_uploadBaseUrl/files/$fileId?uploadType=media'),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: content,
    );
    if (mediaResponse.statusCode == 404) return false;
    _throwDriveError(mediaResponse, operation: 'update the published protocol');
    final metadataResponse = await _client.patch(
      Uri.parse('$_baseUrl/files/$fileId'),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'name': fileName}),
    );
    // The manifest content is authoritative; a stale display name must not
    // roll back a version that is already referenced by the public manifest.
    if (metadataResponse.statusCode == 404) return true;
    return true;
  }

  Future<String> _ensureAnyoneReader(
    String fileId,
    Map<String, String> headers, {
    List<_GrantedPermission>? trackNewPermission,
  }) async {
    final existing = await _findAnyoneReaderPermission(fileId, headers);
    if (existing != null) return existing;
    final response = await _client.post(
      Uri.parse('$_baseUrl/files/$fileId/permissions?fields=id'),
      headers: {...headers, 'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'type': 'anyone',
        'role': 'reader',
        'allowFileDiscovery': false,
      }),
    );
    if (response.statusCode == 403) {
      throw const PublicationException(
        'Your Google Workspace administrator does not allow public Drive links. The protocol was kept private and was not published.',
        sharingBlocked: true,
      );
    }
    _throwDriveError(response, operation: 'enable public viewing');
    final permissionId =
        (jsonDecode(response.body) as Map)['id']?.toString() ?? '';
    if (permissionId.isNotEmpty) {
      trackNewPermission?.add(
        _GrantedPermission(fileId: fileId, permissionId: permissionId),
      );
    }
    return permissionId;
  }

  Future<String?> _findAnyoneReaderPermission(
    String fileId,
    Map<String, String> headers,
  ) async {
    final response = await _client.get(
      Uri.parse(
        '$_baseUrl/files/$fileId/permissions?fields=permissions(id,type,role)',
      ),
      headers: headers,
    );
    if (response.statusCode == 404) return null;
    _throwDriveError(response, operation: 'check public access');
    final decoded = jsonDecode(response.body);
    for (final raw
        in decoded is Map ? decoded['permissions'] as List? ?? [] : []) {
      if (raw is Map && raw['type'] == 'anyone' && raw['role'] == 'reader') {
        return raw['id']?.toString();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _loadFileMetadata(
    String fileId,
    Map<String, String> headers,
  ) async {
    final response = await _client.get(
      Uri.parse(
        '$_baseUrl/files/$fileId?fields=id,resourceKey,webContentLink,webViewLink',
      ),
      headers: headers,
    );
    _throwDriveError(response, operation: 'load the sharing link');
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> _bestEffortDelete(
    String fileId,
    Map<String, String> headers,
  ) async {
    try {
      await _client.delete(
        Uri.parse('$_baseUrl/files/$fileId'),
        headers: headers,
      );
    } catch (_) {
      // The failed publication remains private if rollback cannot complete.
    }
  }

  Future<void> _bestEffortRemovePermission(
    _GrantedPermission permission,
    Map<String, String> headers,
  ) async {
    try {
      await _client.delete(
        Uri.parse(
          '$_baseUrl/files/${permission.fileId}/permissions/${permission.permissionId}',
        ),
        headers: headers,
      );
    } catch (_) {
      // Restore as much of the prior private state as Drive allows.
    }
  }

  void _throwDriveError(http.Response response, {required String operation}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var details = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) details = error['message']?.toString() ?? '';
      }
    } catch (_) {
      details = '';
    }
    throw PublicationException(
      details.isEmpty
          ? 'Google Drive could not $operation (${response.statusCode}).'
          : 'Google Drive could not $operation: $details',
    );
  }

  String _newPublicationId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return 'PUB-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$random';
  }

  String _publishedFileName(String title) {
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '${safe.isEmpty ? 'Protocol' : safe}.protocolflow.json';
  }

  String _publishedVersionFileName(String title, int version) {
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '${safe.isEmpty ? 'Protocol' : safe}.v$version.protocolflow.json';
  }
}
