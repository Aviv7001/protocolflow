import 'dart:io' show File;

import 'package:flutter/material.dart';

Widget buildLocalImage(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(File(path), fit: fit);
}
