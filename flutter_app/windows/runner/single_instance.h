// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 单实例启动认证
//
//   文件:       flutter_app/windows/runner/single_instance.h
//
//   日期:       2026年08月22日
//   环境:       Windows 10/11 x64、ARM64；MSVC；Win32
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   CreateMutexW；GetTokenInformation；SendMessageTimeoutW
// --------------------------------------------------------------------------

#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

namespace taskmgr {

inline constexpr wchar_t kWindowClassName[] =
    L"FLUTTER_RUNNER_WIN32_WINDOW";

// The registered message is used only after the receiver's process identity
// has been authenticated. The receiver returns the same value as an ACK.
UINT ActivationMessage();

class StartupMutex {
 public:
  StartupMutex() = default;
  ~StartupMutex();

  StartupMutex(const StartupMutex&) = delete;
  StartupMutex& operator=(const StartupMutex&) = delete;
  StartupMutex(StartupMutex&& other) noexcept;
  StartupMutex& operator=(StartupMutex&& other) noexcept;

  // Creates the user/session-scoped mutex and waits at most |timeout_ms| for
  // an existing startup owner. Failures deliberately continue unlocked.
  static StartupMutex Acquire(DWORD timeout_ms);

  void Release();

 private:
  StartupMutex(HANDLE handle, bool owned) : handle_(handle), owned_(owned) {}

  HANDLE handle_ = nullptr;
  bool owned_ = false;
};

// A matching class name is never trusted by itself. The candidate must match
// the current user, session, elevation, integrity level, and full image path;
// its HWND/PID binding is checked before and after the bounded send.
bool ActivateAuthenticatedInstance(UINT message, DWORD timeout_ms);

}  // namespace taskmgr

#endif  // RUNNER_SINGLE_INSTANCE_H_
