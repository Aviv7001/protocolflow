import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

@JS('ClipboardItem')
extension type _ClipboardItem._(JSObject _) implements JSObject {
  external factory _ClipboardItem(JSObject items);
}

extension type _Clipboard._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSArray<JSObject> data);
}

class RichClipboardService {
  const RichClipboardService();

  Future<void> copyTable({
    required String plainText,
    required String html,
  }) async {
    try {
      final clipboardObject = web.window.navigator.getProperty<JSObject?>(
        'clipboard'.toJS,
      );
      if (clipboardObject == null) {
        await Clipboard.setData(ClipboardData(text: plainText));
        return;
      }

      final itemData = JSObject()
        ..setProperty(
          'text/html'.toJS,
          web.Blob([html.toJS].toJS, web.BlobPropertyBag(type: 'text/html')),
        )
        ..setProperty(
          'text/plain'.toJS,
          web.Blob(
            [plainText.toJS].toJS,
            web.BlobPropertyBag(type: 'text/plain'),
          ),
        );
      final item = _ClipboardItem(itemData);
      await _Clipboard._(clipboardObject).write([item].toJS).toDart;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: plainText));
    }
  }
}
