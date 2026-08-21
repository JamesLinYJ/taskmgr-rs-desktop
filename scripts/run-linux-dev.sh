#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - Linux Flutter 开发启动器
#
#   文件:       scripts/run-linux-dev.sh
#
#   日期:       2026年08月21日
#   环境:       Fedora/Ubuntu Linux x64/ARM64；Flutter 3.44.7；Wayland/X11
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   Desktop Entry Specification；XDG Base Directory；GNOME Shell Extension CLI；X-KDE-Wayland-Interfaces
# --------------------------------------------------------------------------

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
flutter_bin=${FLUTTER_BIN:-flutter}
application_id=org.taskmgr_rs.TaskManager
build_application=true
extension_staging=

cleanup() {
  if [[ -n "$extension_staging" && -d "$extension_staging" &&
        "$extension_staging" == "${TMPDIR:-/tmp}"/taskmgr-gnome-extension.* ]]; then
    rm -rf -- "$extension_staging"
  fi
}
trap cleanup EXIT INT TERM

if [[ ${1:-} == --no-build ]]; then
  build_application=false
  shift
fi

for command_name in "$flutter_bin" cmp desktop-file-install realpath; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "required command is unavailable: $command_name" >&2
    exit 1
  fi
done

if [[ $build_application == true ]]; then
  (cd "$repo_root/flutter_app" && "$flutter_bin" build linux --debug)
fi

case "$(uname -m)" in
  x86_64) flutter_arch=x64 ;;
  aarch64|arm64) flutter_arch=arm64 ;;
  *) echo "unsupported development architecture: $(uname -m)" >&2; exit 1 ;;
esac

executable=$(realpath "$repo_root/flutter_app/build/linux/$flutter_arch/debug/bundle/taskmgr_rs")
if [[ ! -x "$executable" ]]; then
  echo "Flutter debug executable does not exist: $executable" >&2
  exit 1
fi

data_home=${XDG_DATA_HOME:-${HOME:?HOME is required}/.local/share}
applications_dir="$data_home/applications"
desktop_path="$applications_dir/$application_id.desktop"
install -d -m 0755 "$applications_dir"
desktop-file-install \
  --dir="$applications_dir" \
  --set-key=Exec \
  --set-value="$executable" \
  --set-key=TryExec \
  --set-value="$executable" \
  "$repo_root/packaging/linux/$application_id.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir"
fi

desktop_name=${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-}}
if [[ ${XDG_SESSION_TYPE:-} == wayland && $desktop_name =~ (KDE|Plasma) ]]; then
  sycoca_command=
  for candidate in kbuildsycoca6 kbuildsycoca5; do
    if command -v "$candidate" >/dev/null 2>&1; then
      sycoca_command=$candidate
      break
    fi
  done
  if [[ -z "$sycoca_command" ]]; then
    echo "KDE Wayland requires kbuildsycoca6 or kbuildsycoca5" >&2
    exit 1
  fi
  "$sycoca_command" --noincremental
fi

if [[ ${XDG_SESSION_TYPE:-} == wayland && $desktop_name =~ GNOME ]]; then
  if ! command -v gnome-extensions >/dev/null 2>&1; then
    echo "GNOME Wayland requires gnome-extensions to grant window-list access" >&2
    exit 1
  fi
  extension_uuid=window-provider@org.taskmgr_rs.TaskManager
  extension_source="$repo_root/packaging/linux/gnome-shell-extension/$extension_uuid"
  extension_target="$data_home/gnome-shell/extensions/$extension_uuid"
  extension_changed=false
  if [[ ! -f "$extension_target/metadata.json" ||
        ! -f "$extension_target/extension.js" ]] ||
     ! cmp -s "$extension_source/metadata.json" "$extension_target/metadata.json" ||
     ! cmp -s "$extension_source/extension.js" "$extension_target/extension.js"; then
    extension_changed=true
  fi
  if [[ $extension_changed == true ]]; then
    if gnome-extensions list --enabled | grep -Fxq "$extension_uuid"; then
      gnome-extensions disable "$extension_uuid"
    fi
    extension_staging=$(mktemp -d "${TMPDIR:-/tmp}/taskmgr-gnome-extension.XXXXXX")
    gnome-extensions pack --out-dir="$extension_staging" "$extension_source"
    gnome-extensions install --force \
      "$extension_staging/$extension_uuid.shell-extension.zip"
  fi
  extension_discovered=false
  for _ in {1..20}; do
    if gnome-extensions info "$extension_uuid" >/dev/null 2>&1; then
      extension_discovered=true
      break
    fi
    sleep 0.25
  done
  if [[ $extension_discovered != true ]]; then
    echo "GNOME installed the read-only provider but the running Shell has not discovered it." >&2
    echo "Log out and back in once, then rerun this script." >&2
    exit 1
  fi
  if ! gnome-extensions enable "$extension_uuid"; then
    echo "GNOME discovered the provider but could not enable it in this session." >&2
    echo "Log out and back in once, then rerun this script." >&2
    exit 1
  fi
  if ! gnome-extensions list --enabled | grep -Fxq "$extension_uuid"; then
    echo "GNOME did not report the read-only provider as enabled." >&2
    exit 1
  fi
fi

echo "registered development desktop entry: $desktop_path"
cleanup
trap - EXIT INT TERM
exec "$executable" "$@"
