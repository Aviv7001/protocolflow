import 'dart:convert';

import 'package:flutter/material.dart';

Widget buildLocalImage(String path, {BoxFit fit = BoxFit.cover}) {
  if (path.startsWith('data:image/')) {
    final commaIndex = path.indexOf(',');
    if (commaIndex != -1) {
      final bytes = base64Decode(path.substring(commaIndex + 1));
      return Image.memory(bytes, fit: fit);
    }
  }
  return Image.network(path, fit: fit);
}
