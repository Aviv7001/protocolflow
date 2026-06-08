#include "flutter_window.h"

#include <cstdio>
#include <cstring>
#include <optional>
#include <sstream>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

namespace {

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return L"";
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

bool SetClipboardMemory(UINT format, const void* data, size_t byte_count) {
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, byte_count);
  if (!memory) {
    return false;
  }
  void* target = GlobalLock(memory);
  if (!target) {
    GlobalFree(memory);
    return false;
  }
  memcpy(target, data, byte_count);
  GlobalUnlock(memory);
  if (!SetClipboardData(format, memory)) {
    GlobalFree(memory);
    return false;
  }
  return true;
}

std::string FormatOffset(size_t offset) {
  char buffer[11];
  snprintf(buffer, sizeof(buffer), "%010zu", offset);
  return std::string(buffer);
}

std::string BuildClipboardHtml(const std::string& fragment) {
  const std::string start_marker = "<!--StartFragment-->";
  const std::string end_marker = "<!--EndFragment-->";
  const std::string html =
      "<html><body>" + start_marker + fragment + end_marker + "</body></html>";
  const std::string header_template =
      "Version:0.9\r\n"
      "StartHTML:0000000000\r\n"
      "EndHTML:0000000000\r\n"
      "StartFragment:0000000000\r\n"
      "EndFragment:0000000000\r\n";

  const size_t start_html = header_template.size();
  const size_t end_html = start_html + html.size();
  const size_t start_fragment =
      start_html + html.find(start_marker) + start_marker.size();
  const size_t end_fragment = start_html + html.find(end_marker);

  std::string header = header_template;
  header.replace(header.find("StartHTML:") + 10, 10,
                 FormatOffset(start_html));
  header.replace(header.find("EndHTML:") + 8, 10, FormatOffset(end_html));
  header.replace(header.find("StartFragment:") + 14, 10,
                 FormatOffset(start_fragment));
  header.replace(header.find("EndFragment:") + 12, 10,
                 FormatOffset(end_fragment));
  return header + html;
}

bool CopyRichTableToClipboard(HWND hwnd, const std::string& plain_text,
                              const std::string& html) {
  if (!OpenClipboard(hwnd)) {
    return false;
  }
  EmptyClipboard();

  const std::wstring wide_text = Utf8ToWide(plain_text);
  const bool text_ok = SetClipboardMemory(
      CF_UNICODETEXT, wide_text.c_str(),
      (wide_text.size() + 1) * sizeof(wchar_t));

  const std::string clipboard_html = BuildClipboardHtml(html);
  const UINT html_format = RegisterClipboardFormat(L"HTML Format");
  const bool html_ok = SetClipboardMemory(
      html_format, clipboard_html.c_str(), clipboard_html.size() + 1);

  CloseClipboard();
  return text_ok && html_ok;
}

std::string MapStringValue(const flutter::EncodableMap& map,
                           const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end() || !std::holds_alternative<std::string>(it->second)) {
    return "";
  }
  return std::get<std::string>(it->second);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  rich_clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "protocolflow/rich_clipboard",
          &flutter::StandardMethodCodec::GetInstance());
  rich_clipboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "copyTable") {
          result->NotImplemented();
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!arguments) {
          result->Error("bad_arguments", "Expected clipboard table payload.");
          return;
        }
        const bool success = CopyRichTableToClipboard(
            GetHandle(), MapStringValue(*arguments, "plainText"),
            MapStringValue(*arguments, "html"));
        if (success) {
          result->Success();
        } else {
          result->Error("clipboard_error", "Could not write clipboard data.");
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    rich_clipboard_channel_ = nullptr;
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
