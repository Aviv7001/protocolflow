import 'dart:io' show File;

import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:share_plus/share_plus.dart';

Future<void> saveJsonFileImpl(String content, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'Exported $fileName from ProtocolFlow');
}
