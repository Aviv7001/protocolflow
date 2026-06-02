import 'package:flutter/material.dart';

Widget buildLocalImage(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.network(path, fit: fit);
}
