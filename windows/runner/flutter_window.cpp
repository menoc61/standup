#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstdint>
#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Builds the presence channel wired to Win32's idle counter.
//
// `GetLastInputInfo` reports the tick count of the last keyboard or mouse
// input, so the idle time is the difference to the current tick count. Both
// values are DWORDs that wrap every ~49.7 days; subtracting in DWORD space
// makes the wrap cancel out, which is why the result is taken as unsigned and
// only then widened.
//
// The caller owns the returned channel: destroying it removes the handler.
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreatePresenceChannel(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "standup/presence",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "getIdleTime") {
          result->NotImplemented();
          return;
        }

        LASTINPUTINFO last_input = {};
        last_input.cbSize = sizeof(LASTINPUTINFO);
        if (!GetLastInputInfo(&last_input)) {
          // The API can fail during early logon or session transitions. Report
          // "unknown" rather than zero: a fabricated zero would claim the user
          // is present, and the Dart side treats a null as no information.
          result->Success(flutter::EncodableValue());
          return;
        }

        const DWORD idle_milliseconds = GetTickCount() - last_input.dwTime;
        result->Success(
            flutter::EncodableValue(static_cast<int64_t>(idle_milliseconds)));
      });

  return channel;
}

// Builds the window-chrome channel that raises and lowers the main window.
//
// `HWND_TOPMOST` is a persistent property of the window rather than a one-shot
// raise, so the block stays above other applications without re-asserting on
// every focus change. The window is deliberately not activated or restored here:
// stealing focus is a separate promise (the tray/restore work) and this channel
// only claims stacking order.
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateWindowChannel(flutter::FlutterEngine* engine, Win32Window* window) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "standup/window",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [window](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) {
        if (call.method_name() != "setKeepAbove") {
          result->NotImplemented();
          return;
        }

        // Anything other than an explicit true means "normal stacking", so a
        // malformed argument can only lower the window, never wedge it on top.
        bool keep_above = false;
        const flutter::EncodableValue* arguments = call.arguments();
        if (arguments != nullptr) {
          const auto* map = std::get_if<flutter::EncodableMap>(arguments);
          if (map != nullptr) {
            auto value = map->find(flutter::EncodableValue("value"));
            if (value != map->end()) {
              const auto* flag = std::get_if<bool>(&value->second);
              keep_above = flag != nullptr && *flag;
            }
          }
        }

        HWND handle = window->GetHandle();
        if (handle == nullptr) {
          result->Error("no_window", "The window has already been destroyed");
          return;
        }

        SetWindowPos(handle, keep_above ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0,
                     0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        result->Success();
      });

  return channel;
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
  presence_channel_ = CreatePresenceChannel(flutter_controller_->engine());
  window_channel_ =
      CreateWindowChannel(flutter_controller_->engine(), this);
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
