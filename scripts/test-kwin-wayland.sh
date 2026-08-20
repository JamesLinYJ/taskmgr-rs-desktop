#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - KWin Wayland 桌面集成测试
#
#   文件:       scripts/test-kwin-wayland.sh
#
#   日期:       2026年08月20日
#   环境:       Fedora/Ubuntu Linux x64/ARM64；KWin Wayland；Flutter 3.44.7
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   KDE plasma-window-management；X-KDE-Wayland-Interfaces；Flutter integration_test
# --------------------------------------------------------------------------

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
flutter_bin=${FLUTTER_BIN:-flutter}
for command_name in "$flutter_bin" kwin_wayland timeout zenity; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "required command is unavailable: $command_name" >&2
    exit 1
  fi
done

sycoca_command=
for candidate in kbuildsycoca6 kbuildsycoca5; do
  if command -v "$candidate" >/dev/null 2>&1; then
    sycoca_command=$candidate
    break
  fi
done
if [[ -z "$sycoca_command" ]]; then
  echo "kbuildsycoca6 or kbuildsycoca5 is required" >&2
  exit 1
fi

(cd "$repo_root/flutter_app" && "$flutter_bin" build linux --debug)
architecture=$(uname -m)
case "$architecture" in
  x86_64) flutter_arch=x64 ;;
  aarch64|arm64) flutter_arch=arm64 ;;
  *) echo "unsupported test architecture: $architecture" >&2; exit 1 ;;
esac
bundle="$repo_root/flutter_app/build/linux/$flutter_arch/debug/bundle"
executable=$(realpath "$bundle/taskmgr_rs")

test_root=$(mktemp -d /tmp/taskmgr-rs-wayland.XXXXXX)
runtime_dir="$test_root/runtime"
data_home="$test_root/data"
cache_home="$test_root/cache"
mkdir -p "$runtime_dir" "$data_home/applications" "$cache_home"
chmod 0700 "$runtime_dir"

kwin_pid=
fixture_pid=
cleanup() {
  status=$?
  if ((status != 0)); then
    for log_path in "$test_root/kwin.log" "$test_root/fixture.log"; do
      if [[ -s "$log_path" ]]; then
        echo "===== $log_path =====" >&2
        tail -200 "$log_path" >&2
      fi
    done
  fi
  if [[ -n "$fixture_pid" ]]; then
    kill "$fixture_pid" 2>/dev/null || true
  fi
  if [[ -n "$kwin_pid" ]]; then
    kill "$kwin_pid" 2>/dev/null || true
  fi
  wait "$fixture_pid" "$kwin_pid" 2>/dev/null || true
  if [[ "$test_root" == /tmp/taskmgr-rs-wayland.* ]]; then
    rm -rf -- "$test_root"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

desktop_file="$data_home/applications/io.github.jameslinyj.taskmgr_rs.desktop"
sed "s|^Exec=/usr/bin/taskmgr_rs$|Exec=$executable|" \
  "$repo_root/packaging/linux/io.github.jameslinyj.taskmgr_rs.desktop" \
  > "$desktop_file"

export XDG_RUNTIME_DIR="$runtime_dir"
export XDG_DATA_HOME="$data_home"
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
export XDG_CACHE_HOME="$cache_home"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export WAYLAND_DISPLAY=taskmgr-wayland
export GDK_BACKEND=wayland

"$sycoca_command" --noincremental
QT_QPA_PLATFORM=offscreen kwin_wayland \
  --virtual \
  --socket "$WAYLAND_DISPLAY" \
  --width 800 \
  --height 600 \
  --no-lockscreen \
  --no-global-shortcuts \
  --no-kactivities \
  > "$test_root/kwin.log" 2>&1 &
kwin_pid=$!

for _ in {1..100}; do
  if [[ -S "$runtime_dir/$WAYLAND_DISPLAY" ]]; then
    break
  fi
  if ! kill -0 "$kwin_pid" 2>/dev/null; then
    cat "$test_root/kwin.log" >&2
    exit 1
  fi
  sleep 0.1
done
if [[ ! -S "$runtime_dir/$WAYLAND_DISPLAY" ]]; then
  cat "$test_root/kwin.log" >&2
  echo "KWin did not create the Wayland socket" >&2
  exit 1
fi

zenity \
  --info \
  --title=TaskmgrWaylandFixture \
  --text=TaskmgrWaylandFixture \
  --no-wrap \
  > "$test_root/fixture.log" 2>&1 &
fixture_pid=$!

export TASKMGR_EXPECT_WINDOW_TITLE=TaskmgrWaylandFixture
(
  cd "$repo_root/flutter_app"
  timeout --foreground 180s \
    "$flutter_bin" test integration_test/backend_smoke_test.dart -d linux
)
