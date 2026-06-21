import '../models/protocol.dart';

class ProtocolExportFilename {
  const ProtocolExportFilename._();

  static String protocol(Protocol protocol, String extension) {
    return '${_baseName(protocol)}_protocol.${_extension(extension)}';
  }

  static String completed(
    Protocol protocol,
    DateTime completedAt,
    String extension,
  ) {
    return '${_baseName(protocol)}_completed_${_timestamp(completedAt)}'
        '.${_extension(extension)}';
  }

  static String _baseName(Protocol protocol) {
    final title = _safeSegment(protocol.title, fallback: 'Untitled');
    final id = _safeSegment(protocol.id, fallback: 'unknown');
    return 'ProtocolFlow_${title}_$id';
  }

  static String _safeSegment(String value, {required String fallback}) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? fallback : safe;
  }

  static String _extension(String value) {
    final extension = value.trim().replaceFirst(RegExp(r'^\.+'), '');
    return extension.isEmpty ? 'dat' : extension;
  }

  static String _timestamp(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}'
        '${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}';
  }
}
