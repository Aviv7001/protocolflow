enum ProtocolPublicationStatus {
  published,
  changesUnpublished,
  unpublished;

  static ProtocolPublicationStatus fromJson(dynamic value) {
    return ProtocolPublicationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProtocolPublicationStatus.unpublished,
    );
  }
}

class ProtocolPublication {
  const ProtocolPublication({
    required this.publicationId,
    required this.driveFileId,
    required this.version,
    required this.publishedAt,
    required this.shareUri,
    required this.contentHash,
    required this.ownerGoogleUserId,
    required this.anonymous,
    required this.status,
    this.permissionId,
    this.resourceKey,
    this.authorName,
  });

  final String publicationId;
  final String driveFileId;
  final String? permissionId;
  final String? resourceKey;
  final int version;
  final DateTime publishedAt;
  final String shareUri;
  final String contentHash;
  final String ownerGoogleUserId;
  final String? authorName;
  final bool anonymous;
  final ProtocolPublicationStatus status;

  bool get isPublic => status != ProtocolPublicationStatus.unpublished;

  ProtocolPublication copyWith({
    String? driveFileId,
    String? permissionId,
    String? resourceKey,
    int? version,
    DateTime? publishedAt,
    String? shareUri,
    String? contentHash,
    String? ownerGoogleUserId,
    String? authorName,
    bool? anonymous,
    ProtocolPublicationStatus? status,
  }) {
    return ProtocolPublication(
      publicationId: publicationId,
      driveFileId: driveFileId ?? this.driveFileId,
      permissionId: permissionId ?? this.permissionId,
      resourceKey: resourceKey ?? this.resourceKey,
      version: version ?? this.version,
      publishedAt: publishedAt ?? this.publishedAt,
      shareUri: shareUri ?? this.shareUri,
      contentHash: contentHash ?? this.contentHash,
      ownerGoogleUserId: ownerGoogleUserId ?? this.ownerGoogleUserId,
      authorName: authorName ?? this.authorName,
      anonymous: anonymous ?? this.anonymous,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'publicationId': publicationId,
    'driveFileId': driveFileId,
    'permissionId': permissionId,
    'resourceKey': resourceKey,
    'version': version,
    'publishedAt': publishedAt.toIso8601String(),
    'shareUri': shareUri,
    'contentHash': contentHash,
    'ownerGoogleUserId': ownerGoogleUserId,
    'authorName': authorName,
    'anonymous': anonymous,
    'status': status.name,
  };

  factory ProtocolPublication.fromJson(Map<String, dynamic> json) {
    return ProtocolPublication(
      publicationId: json['publicationId']?.toString() ?? '',
      driveFileId: json['driveFileId']?.toString() ?? '',
      permissionId: json['permissionId']?.toString(),
      resourceKey: json['resourceKey']?.toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      publishedAt:
          DateTime.tryParse(json['publishedAt']?.toString() ?? '') ??
          DateTime.now(),
      shareUri: json['shareUri']?.toString() ?? '',
      contentHash: json['contentHash']?.toString() ?? '',
      ownerGoogleUserId: json['ownerGoogleUserId']?.toString() ?? '',
      authorName: json['authorName']?.toString(),
      anonymous: json['anonymous'] == true,
      status: ProtocolPublicationStatus.fromJson(json['status']),
    );
  }
}

class ProtocolImportSource {
  const ProtocolImportSource({
    required this.publicationId,
    required this.version,
    required this.importedAt,
    required this.shareUri,
    this.authorName,
  });

  final String publicationId;
  final int version;
  final DateTime importedAt;
  final String shareUri;
  final String? authorName;

  Map<String, dynamic> toJson() => {
    'publicationId': publicationId,
    'version': version,
    'importedAt': importedAt.toIso8601String(),
    'shareUri': shareUri,
    'authorName': authorName,
  };

  factory ProtocolImportSource.fromJson(Map<String, dynamic> json) {
    return ProtocolImportSource(
      publicationId: json['publicationId']?.toString() ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      importedAt:
          DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
          DateTime.now(),
      shareUri: json['shareUri']?.toString() ?? '',
      authorName: json['authorName']?.toString(),
    );
  }
}
