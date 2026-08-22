#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - Linux 发布包内容审计
#
#   文件:       scripts/audit-linux-packages.sh
#
#   日期:       2026年08月20日
#   环境:       Linux x64/ARM64；Bash 5；dpkg-deb；RPM 4
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   Debian/RPM 包清单；项目单 cdylib 与 helper 分发契约
# --------------------------------------------------------------------------

set -euo pipefail

directory=${1:?usage: audit-linux-packages.sh <package-directory> [version] [arch]}
version=${2:-0.3.0}
arch=${3:-x64}
application_id=org.taskmgr_rs.TaskManager
extension_uuid=window-provider@org.taskmgr_rs.TaskManager
directory=$(realpath -- "$directory")

portable="$directory/taskmgr-rs-$version-linux-$arch.tar.gz"
if [[ ! -f "$portable" ]]; then
  echo "portable archive is missing: $portable" >&2
  exit 1
fi

mapfile -t portable_files < <(tar -tzf "$portable")
if printf '%s\n' "${portable_files[@]}" | grep -Eq 'taskmgr-helper|polkit|\.policy$'; then
  echo "portable archive contains privileged integration" >&2
  exit 1
fi
if [[ $(printf '%s\n' "${portable_files[@]}" | grep -Ec '/lib/libtaskmgr_native\.so$') -ne 1 ]]; then
  echo "portable archive must contain exactly one Rust taskmgr shared library" >&2
  exit 1
fi
if [[ $(printf '%s\n' "${portable_files[@]}" | grep -Ec '/lib/libtray_manager_plugin\.so$') -ne 1 ]]; then
  echo "portable archive must contain the tray_manager Linux plugin" >&2
  exit 1
fi
for edge in 16 32; do
  if [[ $(printf '%s\n' "${portable_files[@]}" | grep -Ec "/assets/icons/default-process-${edge}\\.png$") -ne 1 ]]; then
    echo "portable archive must contain the classic ${edge}px default application icon" >&2
    exit 1
  fi
done
for extension_file in metadata.json extension.js authorization.js; do
  if [[ $(printf '%s\n' "${portable_files[@]}" | grep -Ec "/share/gnome-shell/extensions/$extension_uuid/$extension_file$") -ne 1 ]]; then
    echo "portable archive must contain GNOME provider file: $extension_file" >&2
    exit 1
  fi
done

mapfile -t rpm_files < <(find "$directory" -maxdepth 1 -type f -name 'taskmgr-rs-*.rpm' -print)
if [[ ${#rpm_files[@]} -gt 0 ]]; then
  if ! command -v rpm >/dev/null 2>&1; then
    echo "rpm is required to audit the generated RPM" >&2
    exit 1
  fi
  for package in "${rpm_files[@]}"; do
    listing=$(rpm -qlp "$package")
    grep -qx '/usr/libexec/taskmgr-rs/taskmgr-helper' <<<"$listing"
    grep -qx "/usr/share/applications/$application_id.desktop" <<<"$listing"
    grep -qx "/usr/share/polkit-1/actions/$application_id.policy" <<<"$listing"
    grep -qx "/usr/share/gnome-shell/extensions/$extension_uuid/metadata.json" <<<"$listing"
    grep -qx "/usr/share/gnome-shell/extensions/$extension_uuid/extension.js" <<<"$listing"
    grep -qx "/usr/share/gnome-shell/extensions/$extension_uuid/authorization.js" <<<"$listing"
    for edge in 16 32 48 64 256; do
      grep -qx "/usr/share/icons/hicolor/${edge}x${edge}/apps/$application_id.png" <<<"$listing"
    done
    if [[ $(grep -Ec '/libtaskmgr_native\.so$' <<<"$listing") -ne 1 ]]; then
      echo "RPM must contain exactly one Rust taskmgr shared library: $package" >&2
      exit 1
    fi
    grep -Eq '/libtray_manager_plugin\.so$' <<<"$listing"
    grep -Eq '/assets/icons/default-process-16\.png$' <<<"$listing"
    grep -Eq '/assets/icons/default-process-32\.png$' <<<"$listing"
    rpm -qlvp "$package" | grep -Eq '^-rwxr-xr-x[[:space:]]+1 root[[:space:]]+root.*taskmgr-helper$'
  done
fi

mapfile -t deb_files < <(find "$directory" -maxdepth 1 -type f -name 'taskmgr-rs_*.deb' -print)
if [[ ${#deb_files[@]} -gt 0 ]]; then
  if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "dpkg-deb is required to audit the generated DEB" >&2
    exit 1
  fi
  for package in "${deb_files[@]}"; do
    listing=$(dpkg-deb --contents "$package")
    grep -Eq '\./usr/libexec/taskmgr-rs/taskmgr-helper$' <<<"$listing"
    grep -Eq "\./usr/share/applications/$application_id\.desktop$" <<<"$listing"
    grep -Eq "\./usr/share/polkit-1/actions/$application_id\.policy$" <<<"$listing"
    grep -Eq "\./usr/share/gnome-shell/extensions/$extension_uuid/metadata\.json$" <<<"$listing"
    grep -Eq "\./usr/share/gnome-shell/extensions/$extension_uuid/extension\.js$" <<<"$listing"
    grep -Eq "\./usr/share/gnome-shell/extensions/$extension_uuid/authorization\.js$" <<<"$listing"
    for edge in 16 32 48 64 256; do
      grep -Eq "\./usr/share/icons/hicolor/${edge}x${edge}/apps/$application_id\.png$" <<<"$listing"
    done
    if [[ $(grep -Ec '/libtaskmgr_native\.so$' <<<"$listing") -ne 1 ]]; then
      echo "DEB must contain exactly one Rust taskmgr shared library: $package" >&2
      exit 1
    fi
    grep -Eq '/libtray_manager_plugin\.so$' <<<"$listing"
    grep -Eq '/assets/icons/default-process-16\.png$' <<<"$listing"
    grep -Eq '/assets/icons/default-process-32\.png$' <<<"$listing"
  done
fi

(
  cd "$directory"
  sha256sum --check SHA256SUMS
)

echo "Linux package audit passed: $directory"
