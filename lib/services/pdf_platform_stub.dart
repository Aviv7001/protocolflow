import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

bool get isWeb => false;

Future<pw.ThemeData> loadPdfTheme() async => pw.ThemeData();

Future<void> layoutPdf(Uint8List bytes, {required String name}) {
  throw UnsupportedError('PDF printing is only available in Flutter.');
}
