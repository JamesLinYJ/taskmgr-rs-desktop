// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows Flutter 桌面入口
//
//   文件:       flutter_app/windows/runner/main.cpp
//
//   日期:       2026年08月21日
//   环境:       Windows 10/11 x64、ARM64；Flutter 3.44.7；Win32
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Win32 wWinMain；Flutter Windows runner；项目窗口尺寸契约
// --------------------------------------------------------------------------

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "single_instance.h"
#include "utils.h"

namespace {
constexpr wchar_t kDefaultWindowTitle[] = L"Windows NT Task Manager";
constexpr int kOriginalWindowWidth = 396;
constexpr int kOriginalWindowHeight = 401;
constexpr DWORD kStartupMutexWaitMilliseconds = 2000;
constexpr DWORD kActivationTimeoutMilliseconds = 2000;
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  auto startup_mutex =
      taskmgr::StartupMutex::Acquire(kStartupMutexWaitMilliseconds);
  const UINT activation_message = taskmgr::ActivationMessage();
  if (taskmgr::ActivateAuthenticatedInstance(
          activation_message, kActivationTimeoutMilliseconds)) {
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(kOriginalWindowWidth, kOriginalWindowHeight);
  if (!window.Create(kDefaultWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  // A live, authenticated HWND can now receive the activation message. Do not
  // retain the startup gate for the lifetime of the application.
  startup_mutex.Release();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
