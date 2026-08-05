import 'dart:convert';

import '../utils/protocol_id.dart';
import 'protocol.dart';
import 'protocol_additional_data.dart';
import 'protocol_publication.dart';

class PublishedProtocolPackage {
  static const String kind = 'protocolflowPublishedProtocol';
  static const int currentSchemaVersion = 1;

  const PublishedProtocolPackage({
    required this.publicationId,
    required this.version,
    required this.publishedAt,
    required this.protocol,
    required this.contentHash,
    this.authorName,
  });

  final String publicationId;
  final int version;
  final DateTime publishedAt;
  final String? authorName;
  final Protocol protocol;
  final String contentHash;

  factory PublishedProtocolPackage.create({
    required Protocol source,
    required String publicationId,
    required int version,
    required DateTime publishedAt,
    required String? authorName,
  }) {
    final sanitized = _sanitizeProtocol(
      source,
      publicationId: publicationId,
      authorName: authorName,
    );
    return PublishedProtocolPackage(
      publicationId: publicationId,
      version: version,
      publishedAt: publishedAt,
      authorName: authorName,
      protocol: sanitized,
      contentHash: publishedProtocolContentHash(sanitized),
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'schemaVersion': currentSchemaVersion,
    'publicationId': publicationId,
    'version': version,
    'publishedAt': publishedAt.toUtc().toIso8601String(),
    'authorName': authorName,
    'contentHash': contentHash,
    'protocol': protocol.toJson(),
  };

  factory PublishedProtocolPackage.fromJson(Map<String, dynamic> json) {
    if (json['kind'] != kind ||
        (json['schemaVersion'] as num?)?.toInt() != currentSchemaVersion) {
      throw const FormatException('Unsupported shared protocol format.');
    }
    final publicationId = json['publicationId']?.toString().trim() ?? '';
    final version = (json['version'] as num?)?.toInt() ?? 0;
    final publishedAt = DateTime.tryParse(
      json['publishedAt']?.toString() ?? '',
    );
    final rawProtocol = json['protocol'];
    if (publicationId.isEmpty ||
        version < 1 ||
        publishedAt == null ||
        rawProtocol is! Map) {
      throw const FormatException('Shared protocol metadata is incomplete.');
    }
    final protocol = Protocol.fromJson(Map<String, dynamic>.from(rawProtocol));
    if (protocol.title.trim().isEmpty || protocol.id != publicationId) {
      throw const FormatException('Shared protocol content is invalid.');
    }
    final expectedHash = publishedProtocolContentHash(protocol);
    final storedHash = json['contentHash']?.toString() ?? '';
    if (storedHash.isEmpty || storedHash != expectedHash) {
      throw const FormatException('Shared protocol integrity check failed.');
    }
    return PublishedProtocolPackage(
      publicationId: publicationId,
      version: version,
      publishedAt: publishedAt,
      authorName: json['authorName']?.toString(),
      protocol: protocol,
      contentHash: storedHash,
    );
  }

  Protocol toImportedProtocol({
    required String shareUri,
    String? localProtocolId,
    String? ownerId,
    ProtocolSyncStatus syncStatus = ProtocolSyncStatus.localOnly,
    String? projectId,
    DateTime? originalCreatedAt,
  }) {
    final now = DateTime.now();
    return Protocol(
      id: localProtocolId ?? generateProtocolId(),
      title: protocol.title,
      objective: protocol.objective,
      description: protocol.description,
      ownerId: ownerId,
      projectId: projectId,
      createdByName: authorName,
      createdAt: originalCreatedAt ?? now,
      updatedAt: now,
      syncStatus: syncStatus,
      materials: protocol.materials,
      materialListTableId: protocol.materialListTableId,
      samples: protocol.samples,
      files: const [],
      steps: protocol.steps,
      tables: protocol.tables,
      additionalData: protocol.additionalData,
      isTemplate: false,
      importSource: ProtocolImportSource(
        publicationId: publicationId,
        version: version,
        importedAt: now,
        shareUri: shareUri,
        authorName: authorName,
      ),
    );
  }
}

Protocol _sanitizeProtocol(
  Protocol source, {
  required String publicationId,
  required String? authorName,
}) {
  return Protocol(
    id: publicationId,
    title: source.title,
    objective: source.objective,
    description: source.description,
    createdByName: authorName,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    syncStatus: ProtocolSyncStatus.localOnly,
    materials: source.materials,
    materialListTableId: source.materialListTableId,
    samples: source.samples,
    files: const [],
    steps: source.steps,
    tables: source.tables,
    additionalData: source.additionalData
        .map(
          (item) => ProtocolAdditionalData(
            id: item.id,
            title: item.title,
            description: item.description,
            link: item.link,
            photoPaths: const [],
          ),
        )
        .toList(),
    isTemplate: false,
  );
}

String publishedProtocolContentHash(Protocol protocol) {
  final canonical = _canonicalJson(protocol.toJson());
  var hash = 0x811c9dc5;
  for (final unit in canonical.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash.toRadixString(36);
}

String _canonicalJson(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
