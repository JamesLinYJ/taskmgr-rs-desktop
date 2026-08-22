// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 单实例启动认证实现
//
//   文件:       flutter_app/windows/runner/single_instance.cpp
//
//   日期:       2026年08月22日
//   环境:       Windows 10/11 x64、ARM64；MSVC；Win32
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   vendor taskmgr-rs single_instance.rs；Windows token APIs
// --------------------------------------------------------------------------

#include "single_instance.h"

#include <sddl.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <cwchar>
#include <string>
#include <utility>
#include <vector>

namespace taskmgr {
namespace {

constexpr wchar_t kActivationMessageName[] = L"taskmgr-rs.activate.v1";
constexpr size_t kMaximumImagePathUnits = 32768;

class UniqueHandle {
 public:
  UniqueHandle() = default;
  explicit UniqueHandle(HANDLE handle) : handle_(handle) {}
  ~UniqueHandle() {
    if (handle_ != nullptr) {
      ::CloseHandle(handle_);
    }
  }

  UniqueHandle(const UniqueHandle&) = delete;
  UniqueHandle& operator=(const UniqueHandle&) = delete;
  UniqueHandle(UniqueHandle&& other) noexcept
      : handle_(std::exchange(other.handle_, nullptr)) {}
  UniqueHandle& operator=(UniqueHandle&& other) noexcept {
    if (this != &other) {
      if (handle_ != nullptr) {
        ::CloseHandle(handle_);
      }
      handle_ = std::exchange(other.handle_, nullptr);
    }
    return *this;
  }

  HANDLE get() const { return handle_; }
  explicit operator bool() const { return handle_ != nullptr; }

 private:
  HANDLE handle_ = nullptr;
};

class LocalAllocation {
 public:
  explicit LocalAllocation(HLOCAL value = nullptr) : value_(value) {}
  ~LocalAllocation() {
    if (value_ != nullptr) {
      ::LocalFree(value_);
    }
  }

  LocalAllocation(const LocalAllocation&) = delete;
  LocalAllocation& operator=(const LocalAllocation&) = delete;
  LocalAllocation(LocalAllocation&& other) noexcept
      : value_(std::exchange(other.value_, nullptr)) {}

  void* get() const { return value_; }

 private:
  HLOCAL value_ = nullptr;
};

struct OwnedSid {
  std::vector<std::uint64_t> storage;
  DWORD byte_length = 0;

  PSID get() const {
    return reinterpret_cast<PSID>(
        const_cast<std::uint64_t*>(storage.data()));
  }
};

struct ProcessIdentity {
  DWORD process_id = 0;
  DWORD session_id = 0;
  bool elevated = false;
  DWORD integrity_rid = 0;
  OwnedSid user_sid;
  std::wstring image_path;
};

bool CopySidOwned(PSID source, OwnedSid* destination) {
  if (source == nullptr || destination == nullptr || !::IsValidSid(source)) {
    return false;
  }
  const DWORD length = ::GetLengthSid(source);
  if (length == 0) {
    return false;
  }
  const size_t words =
      (static_cast<size_t>(length) + sizeof(std::uint64_t) - 1) /
      sizeof(std::uint64_t);
  destination->storage.assign(words, 0);
  destination->byte_length = length;
  return ::CopySid(length, destination->get(), source) != FALSE;
}

bool QueryTokenInformationBuffer(HANDLE token,
                                 TOKEN_INFORMATION_CLASS information_class,
                                 std::vector<std::uint64_t>* output) {
  if (output == nullptr) {
    return false;
  }
  DWORD required = 0;
  ::GetTokenInformation(token, information_class, nullptr, 0, &required);
  if (required == 0) {
    return false;
  }
  const size_t words =
      (static_cast<size_t>(required) + sizeof(std::uint64_t) - 1) /
      sizeof(std::uint64_t);
  output->assign(words, 0);
  return ::GetTokenInformation(token, information_class, output->data(),
                               required, &required) != FALSE;
}

bool QueryProcessIdentity(HANDLE process,
                          DWORD process_id,
                          ProcessIdentity* output) {
  if (process == nullptr || process_id == 0 || output == nullptr) {
    return false;
  }
  ProcessIdentity identity;
  identity.process_id = process_id;
  if (::ProcessIdToSessionId(process_id, &identity.session_id) == FALSE) {
    return false;
  }

  HANDLE raw_token = nullptr;
  if (::OpenProcessToken(process, TOKEN_QUERY, &raw_token) == FALSE) {
    return false;
  }
  const UniqueHandle token(raw_token);

  std::vector<std::uint64_t> elevation_buffer;
  if (!QueryTokenInformationBuffer(token.get(), TokenElevation,
                                   &elevation_buffer) ||
      elevation_buffer.size() * sizeof(std::uint64_t) <
          sizeof(TOKEN_ELEVATION)) {
    return false;
  }
  const auto* elevation =
      reinterpret_cast<const TOKEN_ELEVATION*>(elevation_buffer.data());
  identity.elevated = elevation->TokenIsElevated != 0;

  std::vector<std::uint64_t> user_buffer;
  if (!QueryTokenInformationBuffer(token.get(), TokenUser, &user_buffer) ||
      user_buffer.size() * sizeof(std::uint64_t) < sizeof(TOKEN_USER)) {
    return false;
  }
  const auto* user = reinterpret_cast<const TOKEN_USER*>(user_buffer.data());
  if (!CopySidOwned(user->User.Sid, &identity.user_sid)) {
    return false;
  }

  std::vector<std::uint64_t> integrity_buffer;
  if (!QueryTokenInformationBuffer(token.get(), TokenIntegrityLevel,
                                   &integrity_buffer) ||
      integrity_buffer.size() * sizeof(std::uint64_t) <
          sizeof(TOKEN_MANDATORY_LABEL)) {
    return false;
  }
  const auto* integrity = reinterpret_cast<const TOKEN_MANDATORY_LABEL*>(
      integrity_buffer.data());
  PSID integrity_sid = integrity->Label.Sid;
  if (integrity_sid == nullptr || !::IsValidSid(integrity_sid)) {
    return false;
  }
  const UCHAR* count = ::GetSidSubAuthorityCount(integrity_sid);
  if (count == nullptr || *count == 0) {
    return false;
  }
  const DWORD* rid = ::GetSidSubAuthority(integrity_sid, *count - 1);
  if (rid == nullptr) {
    return false;
  }
  identity.integrity_rid = *rid;

  std::vector<wchar_t> image_path(kMaximumImagePathUnits, L'\0');
  DWORD image_length = static_cast<DWORD>(image_path.size());
  if (::QueryFullProcessImageNameW(process, 0, image_path.data(),
                                   &image_length) == FALSE ||
      image_length == 0 || image_length >= image_path.size()) {
    return false;
  }
  identity.image_path.assign(image_path.data(), image_length);
  *output = std::move(identity);
  return true;
}

bool SameIdentity(const ProcessIdentity& left,
                  const ProcessIdentity& right) {
  return left.session_id == right.session_id &&
         left.elevated == right.elevated &&
         left.integrity_rid == right.integrity_rid &&
         ::EqualSid(left.user_sid.get(), right.user_sid.get()) != FALSE &&
         ::_wcsicmp(left.image_path.c_str(), right.image_path.c_str()) == 0;
}

bool IsWindowStillBound(HWND window, DWORD process_id, HANDLE process) {
  DWORD observed_process_id = 0;
  const bool has_owner =
      ::GetWindowThreadProcessId(window, &observed_process_id) != 0;
  const bool running = ::WaitForSingleObject(process, 0) == WAIT_TIMEOUT;
  return has_owner && running && process_id != 0 &&
         observed_process_id == process_id;
}

std::wstring SidString(const OwnedSid& sid) {
  wchar_t* raw = nullptr;
  if (::ConvertSidToStringSidW(sid.get(), &raw) == FALSE || raw == nullptr) {
    return std::wstring();
  }
  LocalAllocation allocation(reinterpret_cast<HLOCAL>(raw));
  return std::wstring(raw);
}

std::uint64_t SidHash(const OwnedSid& sid) {
  constexpr std::uint64_t kOffset = 14695981039346656037ULL;
  constexpr std::uint64_t kPrime = 1099511628211ULL;
  std::uint64_t hash = kOffset;
  const auto* bytes = reinterpret_cast<const std::uint8_t*>(sid.storage.data());
  for (DWORD index = 0; index < sid.byte_length; ++index) {
    hash ^= bytes[index];
    hash *= kPrime;
  }
  return hash;
}

bool CurrentIdentity(ProcessIdentity* identity) {
  return QueryProcessIdentity(::GetCurrentProcess(), ::GetCurrentProcessId(),
                              identity);
}

}  // namespace

UINT ActivationMessage() {
  static const UINT message = ::RegisterWindowMessageW(kActivationMessageName);
  return message;
}

StartupMutex::~StartupMutex() {
  Release();
}

StartupMutex::StartupMutex(StartupMutex&& other) noexcept
    : handle_(std::exchange(other.handle_, nullptr)),
      owned_(std::exchange(other.owned_, false)) {}

StartupMutex& StartupMutex::operator=(StartupMutex&& other) noexcept {
  if (this != &other) {
    Release();
    handle_ = std::exchange(other.handle_, nullptr);
    owned_ = std::exchange(other.owned_, false);
  }
  return *this;
}

StartupMutex StartupMutex::Acquire(DWORD timeout_ms) {
  ProcessIdentity identity;
  if (!CurrentIdentity(&identity)) {
    return StartupMutex();
  }
  const std::wstring sid = SidString(identity.user_sid);
  if (sid.empty()) {
    return StartupMutex();
  }

  std::array<wchar_t, 192> mutex_name{};
  const int name_length = ::swprintf_s(
      mutex_name.data(), mutex_name.size(),
      L"Local\\taskmgr-rs.startup.v1.session-%lu.user-%016llx",
      static_cast<unsigned long>(identity.session_id),
      static_cast<unsigned long long>(SidHash(identity.user_sid)));
  if (name_length <= 0) {
    return StartupMutex();
  }

  std::wstring sddl = L"D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;";
  sddl.append(sid);
  sddl.push_back(L')');
  if (identity.elevated) {
    sddl.append(L"S:(ML;;NW;;;HI)");
  }
  PSECURITY_DESCRIPTOR raw_descriptor = nullptr;
  if (::ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, &raw_descriptor, nullptr) == FALSE ||
      raw_descriptor == nullptr) {
    return StartupMutex();
  }
  LocalAllocation descriptor(reinterpret_cast<HLOCAL>(raw_descriptor));
  SECURITY_ATTRIBUTES attributes{};
  attributes.nLength = sizeof(attributes);
  attributes.lpSecurityDescriptor = raw_descriptor;
  attributes.bInheritHandle = FALSE;

  HANDLE handle = ::CreateMutexW(&attributes, TRUE, mutex_name.data());
  if (handle == nullptr) {
    return StartupMutex();
  }
  const DWORD creation_error = ::GetLastError();
  if (creation_error != ERROR_ALREADY_EXISTS) {
    return StartupMutex(handle, true);
  }

  const DWORD wait_result = ::WaitForSingleObject(handle, timeout_ms);
  if (wait_result == WAIT_OBJECT_0 || wait_result == WAIT_ABANDONED) {
    return StartupMutex(handle, true);
  }
  ::CloseHandle(handle);
  return StartupMutex();
}

void StartupMutex::Release() {
  if (handle_ == nullptr) {
    return;
  }
  if (owned_) {
    ::ReleaseMutex(handle_);
  }
  ::CloseHandle(handle_);
  handle_ = nullptr;
  owned_ = false;
}

bool ActivateAuthenticatedInstance(UINT message, DWORD timeout_ms) {
  if (message == 0) {
    return false;
  }
  ProcessIdentity current;
  if (!CurrentIdentity(&current)) {
    return false;
  }

  HWND after = nullptr;
  while (true) {
    const HWND candidate =
        ::FindWindowExW(nullptr, after, kWindowClassName, nullptr);
    if (candidate == nullptr) {
      return false;
    }
    after = candidate;

    DWORD candidate_process_id = 0;
    if (::GetWindowThreadProcessId(candidate, &candidate_process_id) == 0 ||
        candidate_process_id == 0 ||
        candidate_process_id == current.process_id) {
      continue;
    }
    UniqueHandle process(::OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, FALSE,
        candidate_process_id));
    if (!process) {
      continue;
    }
    ProcessIdentity peer;
    if (!QueryProcessIdentity(process.get(), candidate_process_id, &peer) ||
        !SameIdentity(current, peer) ||
        !IsWindowStillBound(candidate, candidate_process_id, process.get())) {
      continue;
    }

    // The newly launched process owns foreground activation rights. Transfer
    // them only to the fully authenticated peer before the bounded message.
    ::AllowSetForegroundWindow(candidate_process_id);
    DWORD_PTR result = 0;
    const LRESULT sent = ::SendMessageTimeoutW(
        candidate, message, 0, 0, SMTO_ABORTIFHUNG | SMTO_BLOCK, timeout_ms,
        &result);
    if (sent != 0 && result == static_cast<DWORD_PTR>(message) &&
        IsWindowStillBound(candidate, candidate_process_id, process.get())) {
      return true;
    }
  }
}

}  // namespace taskmgr
