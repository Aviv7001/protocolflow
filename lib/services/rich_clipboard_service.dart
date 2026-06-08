export 'rich_clipboard_service_stub.dart'
    if (dart.library.html) 'rich_clipboard_service_web.dart'
    if (dart.library.io) 'rich_clipboard_service_io.dart';
