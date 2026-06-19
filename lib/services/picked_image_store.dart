import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedImageStore {
  PickedImageStore._();

  static Future<String> persistPickedImage(XFile image) async {
    if (!kIsWeb) return image.path;

    final bytes = await image.readAsBytes();
    final mimeType = image.mimeType ?? _mimeTypeForName(image.name);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  static String _mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
