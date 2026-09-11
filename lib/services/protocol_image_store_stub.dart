import 'dart:convert';
import 'dart:typed_data';

class ProtocolImageStore {
  const ProtocolImageStore._();

  static Future<Uint8List?> loadBytes(String source) async {
    final comma = source.indexOf(',');
    if (!source.startsWith('data:image/') || comma == -1) return null;
    return base64Decode(source.substring(comma + 1));
  }

  static Future<String> persistEditedImage(Uint8List bytes) async {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }
}
