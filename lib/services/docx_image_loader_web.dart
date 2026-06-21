import 'dart:convert';
import 'dart:typed_data';

Future<Uint8List?> loadDocxImageBytesImpl(String source) async {
  if (!source.startsWith('data:image/')) return null;
  final commaIndex = source.indexOf(',');
  if (commaIndex == -1) return null;
  return base64Decode(source.substring(commaIndex + 1));
}
