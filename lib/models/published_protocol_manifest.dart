class PublishedProtocolVersion {
  const PublishedProtocolVersion({
    required this.version,
    required this.publishedAt,
    required this.fileId,
    required this.contentHash,
    this.authorName,
    this.resourceKey,
  });

  final int version;
  final DateTime publishedAt;
  final String? authorName;
  final String fileId;
  final String? resourceKey;
  final String contentHash;

  Map<String, dynamic> toJson() => {
    'version': version,
    'publishedAt': publishedAt.toUtc().toIso8601String(),
    'authorName': authorName,
    'fileId': fileId,
    'resourceKey': resourceKey,
    'contentHash': contentHash,
  };

  factory PublishedProtocolVersion.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 0;
    final publishedAt = DateTime.tryParse(
      json['publishedAt']?.toString() ?? '',
    );
    final fileId = json['fileId']?.toString().trim() ?? '';
    final contentHash = json['contentHash']?.toString().trim() ?? '';
    if (version < 1 ||
        publishedAt == null ||
        fileId.isEmpty ||
        contentHash.isEmpty) {
      throw const FormatException(
        'Published protocol version metadata is incomplete.',
      );
    }
    return PublishedProtocolVersion(
      version: version,
      publishedAt: publishedAt.toUtc(),
      authorName: _optionalText(json['authorName']),
      fileId: fileId,
      resourceKey: _optionalText(json['resourceKey']),
      contentHash: contentHash,
    );
  }
}

class PublishedProtocolManifest {
  static const String kind = 'protocolflowPublishedProtocolManifest';
  static const int currentSchemaVersion = 1;

  const PublishedProtocolManifest({
    required this.publicationId,
    required this.title,
    required this.latestVersion,
    required this.updatedAt,
    required this.versions,
  });

  final String publicationId;
  final String title;
  final int latestVersion;
  final DateTime updatedAt;
  final List<PublishedProtocolVersion> versions;

  PublishedProtocolVersion version(int number) {
    return versions.firstWhere(
      (entry) => entry.version == number,
      orElse: () => throw const FormatException(
        'The selected published protocol version is unavailable.',
      ),
    );
  }

  PublishedProtocolManifest append({
    required String title,
    required PublishedProtocolVersion entry,
  }) {
    if (entry.version <= latestVersion ||
        versions.any((item) => item.version == entry.version)) {
      throw const FormatException(
        'Published protocol versions must be appended in order.',
      );
    }
    return PublishedProtocolManifest(
      publicationId: publicationId,
      title: title,
      latestVersion: entry.version,
      updatedAt: entry.publishedAt,
      versions: [...versions, entry],
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'schemaVersion': currentSchemaVersion,
    'publicationId': publicationId,
    'title': title,
    'latestVersion': latestVersion,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'versions': versions.map((entry) => entry.toJson()).toList(),
  };

  factory PublishedProtocolManifest.fromJson(Map<String, dynamic> json) {
    if (json['kind'] != kind ||
        (json['schemaVersion'] as num?)?.toInt() != currentSchemaVersion) {
      throw const FormatException(
        'Unsupported published protocol manifest format.',
      );
    }
    final publicationId = json['publicationId']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final latestVersion = (json['latestVersion'] as num?)?.toInt() ?? 0;
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    final rawVersions = json['versions'];
    if (publicationId.isEmpty ||
        title.isEmpty ||
        latestVersion < 1 ||
        updatedAt == null ||
        rawVersions is! List ||
        rawVersions.isEmpty) {
      throw const FormatException(
        'Published protocol manifest metadata is incomplete.',
      );
    }
    final versions = rawVersions.map((raw) {
      if (raw is! Map) {
        throw const FormatException(
          'Published protocol version metadata is invalid.',
        );
      }
      return PublishedProtocolVersion.fromJson(Map<String, dynamic>.from(raw));
    }).toList()..sort((a, b) => a.version.compareTo(b.version));
    final versionNumbers = versions.map((entry) => entry.version).toSet();
    if (versionNumbers.length != versions.length ||
        versions.last.version != latestVersion) {
      throw const FormatException(
        'Published protocol version history is inconsistent.',
      );
    }
    return PublishedProtocolManifest(
      publicationId: publicationId,
      title: title,
      latestVersion: latestVersion,
      updatedAt: updatedAt.toUtc(),
      versions: List.unmodifiable(versions),
    );
  }
}

String? _optionalText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
