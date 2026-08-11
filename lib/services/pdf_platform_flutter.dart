import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

bool get isWeb => kIsWeb;

Future<pw.ThemeData> loadPdfTheme() async {
  final font = await PdfGoogleFonts.arimoRegular();
  final boldFont = await PdfGoogleFonts.arimoBold();
  final italicFont = await PdfGoogleFonts.arimoItalic();
  return pw.ThemeData.withFont(base: font, bold: boldFont, italic: italicFont);
}

Future<void> layoutPdf(Uint8List bytes, {required String name}) {
  return Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => bytes,
    name: name,
    format: PdfPageFormat.a4,
  );
}
