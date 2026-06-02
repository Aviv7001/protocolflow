import 'json_file_saver_stub.dart'
    if (dart.library.io) 'json_file_saver_io.dart'
    if (dart.library.html) 'json_file_saver_web.dart';

Future<void> saveJsonFile(String content, String fileName) {
  return saveJsonFileImpl(content, fileName);
}
