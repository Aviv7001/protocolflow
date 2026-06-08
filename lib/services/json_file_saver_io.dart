import 'dart:typed_data';
import 'dart:io' show Directory, File;

import 'package:path_provider/path_provider.dart'
    show getDownloadsDirectory, getTemporaryDirectory;
import 'package:share_plus/share_plus.dart';

Future<void> saveJsonFileImpl(String content, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Exported $fileName from ProtocolFlow');
}

Future<void> saveBinaryFileImpl(
  Uint8List bytes,
  String fileName, {
  required String mimeType,
}) async {
  final directory = await _downloadDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
}

Future<Directory> _downloadDirectory() async {
  try {
    return await getDownloadsDirectory() ?? await getTemporaryDirectory();
  } catch (_) {
    return getTemporaryDirectory();
  }
}
