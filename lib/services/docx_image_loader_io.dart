import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> loadDocxImageBytesImpl(String source) async {
  if (source.startsWith('data:image/')) {
    final commaIndex = source.indexOf(',');
    if (commaIndex == -1) return null;
    return base64Decode(source.substring(commaIndex + 1));
  }

  final file = File(source);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}
