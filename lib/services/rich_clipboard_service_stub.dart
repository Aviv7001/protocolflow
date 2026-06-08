import 'package:flutter/services.dart';

class RichClipboardService {
  const RichClipboardService();

  Future<void> copyTable({required String plainText, required String html}) {
    return Clipboard.setData(ClipboardData(text: plainText));
  }
}
