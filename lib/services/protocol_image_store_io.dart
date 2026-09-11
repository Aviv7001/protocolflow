import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ProtocolImageStore {
  const ProtocolImageStore._();

  static Future<Uint8List?> loadBytes(String source) async {
    if (source.startsWith('data:image/')) {
      final comma = source.indexOf(',');
      if (comma == -1) return null;
      return base64Decode(source.substring(comma + 1));
    }
    final file = File(source);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<String> persistEditedImage(Uint8List bytes) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/protocolflow_images');
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}/figure_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
