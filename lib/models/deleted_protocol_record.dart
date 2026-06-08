import 'protocol.dart';

class DeletedProtocolRecord {
  final Protocol protocol;
  final DateTime deletedAt;
  final String? driveFileId;

  const DeletedProtocolRecord({
    required this.protocol,
    required this.deletedAt,
    this.driveFileId,
  });

  String get protocolId => protocol.id;

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol.toJson(),
      'deletedAt': deletedAt.toIso8601String(),
      'driveFileId': driveFileId ?? protocol.driveFileId,
    };
  }

  factory DeletedProtocolRecord.fromJson(Map<String, dynamic> json) {
    return DeletedProtocolRecord(
      protocol: Protocol.fromJson(json['protocol']),
      deletedAt: DateTime.tryParse(json['deletedAt'] ?? '') ?? DateTime.now(),
      driveFileId: json['driveFileId'],
    );
  }
}
