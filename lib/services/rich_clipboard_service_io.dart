import 'package:flutter/services.dart';

class RichClipboardService {
  const RichClipboardService();

  static const _channel = MethodChannel('protocolflow/rich_clipboard');

  Future<void> copyTable({
    required String plainText,
    required String html,
  }) async {
    try {
      await _channel.invokeMethod<void>('copyTable', {
        'plainText': plainText,
        'html': html,
      });
    } on PlatformException {
      await Clipboard.setData(ClipboardData(text: plainText));
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: plainText));
    }
  }
}
