import 'dart:typed_data';

import 'docx_image_loader_stub.dart'
    if (dart.library.io) 'docx_image_loader_io.dart'
    if (dart.library.html) 'docx_image_loader_web.dart';

Future<Uint8List?> loadDocxImageBytes(String source) {
  return loadDocxImageBytesImpl(source);
}
