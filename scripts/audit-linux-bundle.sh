#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - Linux Flutter bundle 内容审计
#
#   文件:       scripts/audit-linux-bundle.sh
#
#   日期:       2026年08月20日
#   环境:       Linux x64/ARM64；Bash 5；Flutter 3.44.7
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   Flutter Linux bundle 布局；项目单一 Rust cdylib 契约
# --------------------------------------------------------------------------

set -euo pipefail

bundle=${1:?usage: audit-linux-bundle.sh <bundle-directory>}
if [[ ! -d "$bundle" ]]; then
  echo "bundle directory does not exist: $bundle" >&2
  exit 1
fi
if [[ ! -x "$bundle/taskmgr_rs" ]]; then
  echo "taskmgr_rs executable is missing from $bundle" >&2
  exit 1
fi
if [[ ! -f "$bundle/lib/libflutter_linux_gtk.so" ]]; then
  echo "Flutter engine is missing from $bundle/lib" >&2
  exit 1
fi
if [[ ! -f "$bundle/lib/libtray_manager_plugin.so" ]]; then
  echo "tray_manager Linux plugin is missing from $bundle/lib" >&2
  exit 1
fi
for edge in 16 32; do
  default_application_icon="$bundle/data/flutter_assets/assets/icons/default-process-$edge.png"
  if [[ ! -f "$default_application_icon" ]]; then
    echo "classic ${edge}px default application icon is missing from the bundle" >&2
    exit 1
  fi
done
tray_asset_dir="$bundle/data/flutter_assets/assets/tray"
if [[ ! -d "$tray_asset_dir" ]]; then
  echo "classic CPU tray asset directory is missing from the bundle" >&2
  exit 1
fi
png_tray_assets=$(find "$tray_asset_dir" -maxdepth 1 -type f -name 'cpu-usage-level-*.png' | wc -l)
ico_tray_assets=$(find "$tray_asset_dir" -maxdepth 1 -type f -name 'cpu-usage-level-*.ico' | wc -l)
if [[ $png_tray_assets -ne 12 || $ico_tray_assets -ne 12 ]]; then
  echo "the bundle must contain all 12 classic CPU tray levels as PNG and ICO" >&2
  exit 1
fi

if ! command -v readelf >/dev/null 2>&1; then
  echo "readelf is required to audit Linux runtime paths" >&2
  exit 1
fi
mapfile -t elf_files < <(
  find "$bundle" -type f \( -perm -0100 -o -name '*.so' \) -print | sort
)
for binary in "${elf_files[@]}"; do
  while IFS= read -r runtime_path; do
    IFS=: read -r -a entries <<<"$runtime_path"
    for entry in "${entries[@]}"; do
      if [[ "$entry" != '$ORIGIN' && "$entry" != '$ORIGIN/'* ]]; then
        echo "non-relocatable runtime path in $binary: $entry" >&2
        exit 1
      fi
    done
  done < <(
    readelf -d "$binary" 2>/dev/null \
      | sed -n 's/.*Library r.*path: \[\(.*\)\]/\1/p'
  )
done

mapfile -t native_libraries < <(
  find "$bundle" -type f -name 'libtaskmgr*.so' -print | sort
)
if [[ ${#native_libraries[@]} -ne 1 ]]; then
  printf 'expected exactly one taskmgr Rust shared library, found %d\n' \
    "${#native_libraries[@]}" >&2
  printf '%s\n' "${native_libraries[@]}" >&2
  exit 1
fi
if [[ ${native_libraries[0]} != "$bundle/lib/libtaskmgr_native.so" ]]; then
  echo "unexpected Rust shared library: ${native_libraries[0]}" >&2
  exit 1
fi

echo "bundle audit passed: $bundle"
echo "Rust library: ${native_libraries[0]}"
