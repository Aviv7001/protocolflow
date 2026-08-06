import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protocolflow/models/protocol.dart';
import 'package:protocolflow/models/protocol_publication.dart';
import 'package:protocolflow/models/published_protocol_manifest.dart';
import 'package:protocolflow/models/published_protocol_package.dart';
import 'package:protocolflow/services/protocol_publication_service.dart';

void main() {
  test('sharing link parser accepts ProtocolFlow and Drive links', () {
    final protocolFlow = SharedProtocolLink.tryParse(
      'https://aviv7001.github.io/protocolflow/?import=file-1&resourceKey=key-1',
    );
    final drive = SharedProtocolLink.tryParse(
      'https://drive.google.com/file/d/file-2/view?resourcekey=key-2',
    );

    expect(protocolFlow?.fileId, 'file-1');
    expect(protocolFlow?.resourceKey, 'key-1');
    expect(drive?.fileId, 'file-2');
    expect(drive?.resourceKey, 'key-2');
    expect(
      SharedProtocolLink.tryParse(
        'https://example.com/?import=file-3&version=4',
      )?.version,
      4,
    );
    expect(SharedProtocolLink.tryParse('not a sharing link'), isNull);
  });

  test('shared manifest downloads the selected immutable version', () async {
    var authorizationRequested = false;
    final source = Protocol(
      id: 'private',
      title: 'Versioned protocol',
      objective: '',
      description: '',
      steps: const [],
    );
    final first = PublishedProtocolPackage.create(
      source: source,
      publicationId: 'publication-1',
      version: 1,
      publishedAt: DateTime.utc(2026, 8, 1),
      authorName: 'Author',
    );
    final second = PublishedProtocolPackage.create(
      source: source.copyWith(title: 'Versioned protocol updated'),
      publicationId: 'publication-1',
      version: 2,
      publishedAt: DateTime.utc(2026, 8, 2),
      authorName: 'Author',
    );
    final manifest = PublishedProtocolManifest(
      publicationId: 'publication-1',
      title: second.protocol.title,
      latestVersion: 2,
      updatedAt: second.publishedAt,
      versions: [
        PublishedProtocolVersion(
          version: 1,
          publishedAt: first.publishedAt,
          authorName: first.authorName,
          fileId: 'version-1',
          contentHash: first.contentHash,
        ),
        PublishedProtocolVersion(
          version: 2,
          publishedAt: second.publishedAt,
          authorName: second.authorName,
          fileId: 'version-2',
          contentHash: second.contentHash,
        ),
      ],
    );
    final client = MockClient((request) async {
      final id = request.url.queryParameters['id'];
      if (id == 'manifest-file') {
        return http.Response(jsonEncode(manifest.toJson()), 200);
      }
      if (id == 'version-1') {
        return http.Response(jsonEncode(first.toJson()), 200);
      }
      if (id == 'version-2') {
        return http.Response(jsonEncode(second.toJson()), 200);
      }
      return http.Response('Not found', 404);
    });
    final service = ProtocolPublicationService(
      client: client,
      headersProvider: (_) async {
        authorizationRequested = true;
        throw StateError('Public downloads must not request authorization.');
      },
    );

    final latest = await service.downloadSharedPublication(
      'https://example.com/?import=manifest-file',
    );
    final historical = await service.downloadSharedPublication(
      'https://example.com/?import=manifest-file',
      version: 1,
    );

    expect(latest.package.version, 2);
    expect(latest.manifest.versions, hasLength(2));
    expect(historical.package.version, 1);
    expect(historical.package.protocol.title, 'Versioned protocol');
    expect(authorizationRequested, isFalse);
  });

  test('legacy publication link remains downloadable', () async {
    final package = PublishedProtocolPackage.create(
      source: Protocol(
        id: 'private',
        title: 'Legacy protocol',
        objective: '',
        description: '',
        steps: const [],
      ),
      publicationId: 'publication-legacy',
      version: 3,
      publishedAt: DateTime.utc(2026, 8, 1),
      authorName: null,
    );
    final service = ProtocolPublicationService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(package.toJson()), 200),
      ),
      headersProvider: (_) async => null,
    );

    final download = await service.downloadSharedPublication(
      'https://example.com/?import=legacy-file',
    );

    expect(download.isLegacyPublication, isTrue);
    expect(download.manifest.latestVersion, 3);
    expect(download.package.protocol.title, 'Legacy protocol');
  });

  test('public API key uses the browser-safe Drive media endpoint', () async {
    final package = PublishedProtocolPackage.create(
      source: Protocol(
        id: 'private',
        title: 'Public protocol',
        objective: '',
        description: '',
        steps: const [],
      ),
      publicationId: 'publication-public',
      version: 1,
      publishedAt: DateTime.utc(2026, 8, 6),
      authorName: null,
    );
    late Uri requestedUri;
    final service = ProtocolPublicationService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode(package.toJson()), 200);
      }),
      headersProvider: (_) async => null,
      publicApiKey: 'restricted-browser-key',
    );

    await service.downloadSharedPublication(
      'https://example.com/?import=public-file',
    );

    expect(requestedUri.host, 'www.googleapis.com');
    expect(requestedUri.path, '/drive/v3/files/public-file');
    expect(requestedUri.queryParameters['alt'], 'media');
    expect(requestedUri.queryParameters['key'], 'restricted-browser-key');
  });

  test(
    'publishing migrates a legacy snapshot without changing its link',
    () async {
      final legacy = PublishedProtocolPackage.create(
        source: Protocol(
          id: 'private',
          title: 'Legacy protocol',
          objective: '',
          description: '',
          steps: const [],
        ),
        publicationId: 'publication-1',
        version: 1,
        publishedAt: DateTime.utc(2026, 8, 1),
        authorName: 'Author',
      );
      var uploadNumber = 0;
      Map<String, dynamic>? uploadedManifest;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files' &&
            request.url.queryParameters.containsKey('spaces')) {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'folder'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/root-file' &&
            request.url.queryParameters['alt'] == 'media') {
          return http.Response(jsonEncode(legacy.toJson()), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/upload/drive/v3/files') {
          uploadNumber++;
          return http.Response(
            jsonEncode({'id': uploadNumber == 1 ? 'version-1' : 'version-2'}),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/permissions')) {
          final root = request.url.path.contains('root-file');
          return http.Response(
            jsonEncode({
              'permissions': root
                  ? [
                      {'id': 'root-reader', 'type': 'anyone', 'role': 'reader'},
                    ]
                  : [],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/permissions')) {
          return http.Response(jsonEncode({'id': 'reader'}), 200);
        }
        if (request.method == 'GET' &&
            (request.url.path.endsWith('/version-1') ||
                request.url.path.endsWith('/version-2'))) {
          return http.Response(jsonEncode({'resourceKey': 'resource'}), 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/upload/drive/v3/files/root-file') {
          uploadedManifest = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response('', 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/drive/v3/files/root-file') {
          return http.Response('', 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/root-file') {
          return http.Response(
            jsonEncode({'resourceKey': 'root-resource'}),
            200,
          );
        }
        return http.Response(
          'Unexpected request: ${request.method} ${request.url}',
          500,
        );
      });
      final service = ProtocolPublicationService(
        client: client,
        headersProvider: (_) async => {'Authorization': 'Bearer test'},
      );
      final protocol = legacy.protocol.copyWith(
        id: 'local-protocol',
        publication: ProtocolPublication(
          publicationId: 'publication-1',
          driveFileId: 'root-file',
          permissionId: 'root-reader',
          version: 1,
          publishedAt: legacy.publishedAt,
          shareUri: 'https://example.com/?import=root-file',
          contentHash: legacy.contentHash,
          ownerGoogleUserId: 'owner-1',
          anonymous: false,
          status: ProtocolPublicationStatus.published,
        ),
      );

      final publication = await service.publish(
        protocol: protocol,
        ownerGoogleUserId: 'owner-1',
        authorName: 'Author',
        anonymous: false,
      );

      final manifest = PublishedProtocolManifest.fromJson(uploadedManifest!);
      expect(publication.driveFileId, 'root-file');
      expect(publication.version, 2);
      expect(manifest.versions.map((entry) => entry.version), [1, 2]);
      expect(manifest.version(1).fileId, 'version-1');
      expect(manifest.version(2).fileId, 'version-2');
    },
  );

  test('corporate public-sharing restriction is reported clearly', () async {
    var folderNumber = 0;
    var rolledBack = false;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files' &&
          request.url.queryParameters.containsKey('spaces')) {
        return http.Response(jsonEncode({'files': []}), 200);
      }
      if (request.method == 'POST' && request.url.path == '/drive/v3/files') {
        folderNumber++;
        return http.Response(jsonEncode({'id': 'folder-$folderNumber'}), 200);
      }
      if (request.method == 'POST' &&
          request.url.path == '/upload/drive/v3/files') {
        return http.Response(jsonEncode({'id': 'published-file'}), 200);
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/published-file/permissions')) {
        return http.Response(jsonEncode({'permissions': []}), 200);
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/published-file/permissions')) {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Sharing outside this domain is disabled.'},
          }),
          403,
        );
      }
      if (request.method == 'DELETE' &&
          request.url.path.endsWith('/published-file')) {
        rolledBack = true;
        return http.Response('', 204);
      }
      return http.Response(
        'Unexpected request: ${request.method} ${request.url}',
        500,
      );
    });
    final service = ProtocolPublicationService(
      client: client,
      headersProvider: (_) async => {'Authorization': 'Bearer test'},
    );
    final protocol = Protocol(
      id: 'protocol-1',
      title: 'Restricted publication',
      objective: '',
      description: '',
      steps: const [],
    );

    await expectLater(
      service.publish(
        protocol: protocol,
        ownerGoogleUserId: 'owner-1',
        authorName: 'Owner',
        anonymous: false,
      ),
      throwsA(
        isA<PublicationException>()
            .having((error) => error.sharingBlocked, 'sharingBlocked', isTrue)
            .having(
              (error) => error.message,
              'message',
              contains('administrator'),
            ),
      ),
    );
    expect(rolledBack, isTrue);
  });
}
