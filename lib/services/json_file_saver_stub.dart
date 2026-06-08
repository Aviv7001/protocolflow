import 'dart:typed_data';

Future<void> saveJsonFileImpl(String content, String fileName) {
  throw UnsupportedError('JSON export is not supported on this platform.');
}

Future<void> saveBinaryFileImpl(
  Uint8List bytes,
  String fileName, {
  required String mimeType,
}) {
  throw UnsupportedError('Binary export is not supported on this platform.');
}
