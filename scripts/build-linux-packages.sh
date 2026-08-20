#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - Linux 发布包构建
#
#   文件:       scripts/build-linux-packages.sh
#
#   日期:       2026年08月20日
#   环境:       Linux x64/ARM64；Bash 5；dpkg-deb；RPM 4
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   Debian binary package；RPM Packaging Guide；FHS；polkit
# --------------------------------------------------------------------------

set -euo pipefail

bundle=${1:?usage: build-linux-packages.sh <bundle> <helper> [output] [version]}
helper=${2:?usage: build-linux-packages.sh <bundle> <helper> [output] [version]}
output=${3:-dist}
version=${4:-0.3.0}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
bundle=$(realpath -- "$bundle")
helper=$(realpath -- "$helper")
mkdir -p -- "$output"
output=$(realpath -- "$output")

if [[ ! -d "$bundle" || ! -x "$bundle/taskmgr_rs" ]]; then
  echo "invalid Flutter Linux bundle: $bundle" >&2
  exit 1
fi
if [[ ! -x "$helper" ]]; then
  echo "taskmgr-helper is missing or not executable: $helper" >&2
  exit 1
fi
"$repo_root/scripts/audit-linux-bundle.sh" "$bundle"

case $(uname -m) in
  x86_64) portable_arch=x64; deb_arch=amd64 ;;
  aarch64|arm64) portable_arch=arm64; deb_arch=arm64 ;;
  *) echo "unsupported packaging architecture: $(uname -m)" >&2; exit 1 ;;
esac

stage_root=$(mktemp -d "${TMPDIR:-/tmp}/taskmgr-rs-package.XXXXXX")
cleanup() {
  if [[ "$stage_root" == "${TMPDIR:-/tmp}"/taskmgr-rs-package.* ]]; then
    rm -rf -- "$stage_root"
  fi
}
trap cleanup EXIT INT TERM

portable_name="taskmgr-rs-$version-linux-$portable_arch"
portable_root="$stage_root/$portable_name"
mkdir -p -- "$portable_root"
cp -a -- "$bundle/." "$portable_root/"
cp -a -- "$repo_root/LICENSE" "$portable_root/LICENSE"
tar \
  --sort=name \
  --mtime="@${SOURCE_DATE_EPOCH:-0}" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -C "$stage_root" \
  -czf "$output/$portable_name.tar.gz" \
  "$portable_name"
if tar -tzf "$output/$portable_name.tar.gz" | grep -q 'taskmgr-helper'; then
  echo "portable archive must not contain the privileged helper" >&2
  exit 1
fi

install_tree() {
  local root=$1
  install -d "$root/usr/lib/taskmgr-rs"
  cp -a -- "$bundle/." "$root/usr/lib/taskmgr-rs/"
  install -Dpm0755 "$helper" "$root/usr/libexec/taskmgr-rs/taskmgr-helper"
  install -Dpm0755 \
    "$repo_root/packaging/linux/taskmgr_rs-launcher" \
    "$root/usr/bin/taskmgr_rs"
  install -Dpm0644 \
    "$repo_root/packaging/linux/io.github.jameslinyj.taskmgr_rs.desktop" \
    "$root/usr/share/applications/io.github.jameslinyj.taskmgr_rs.desktop"
  install -Dpm0644 \
    "$repo_root/packaging/linux/io.github.jameslinyj.taskmgr_rs.policy" \
    "$root/usr/share/polkit-1/actions/io.github.jameslinyj.taskmgr_rs.policy"
  install -d "$root/usr/share/icons/hicolor"
  cp -a -- \
    "$repo_root/packaging/linux/icons/hicolor/." \
    "$root/usr/share/icons/hicolor/"
  install -Dpm0644 "$repo_root/LICENSE" \
    "$root/usr/share/doc/taskmgr-rs/copyright"
}

if command -v dpkg-deb >/dev/null 2>&1; then
  deb_root="$stage_root/deb-root"
  install_tree "$deb_root"
  install -d "$deb_root/DEBIAN"
  sed \
    -e "s/@VERSION@/$version/g" \
    -e "s/@ARCHITECTURE@/$deb_arch/g" \
    "$repo_root/packaging/linux/debian-control.in" \
    > "$deb_root/DEBIAN/control"
  chmod 0644 "$deb_root/DEBIAN/control"
  dpkg-deb --root-owner-group --build \
    "$deb_root" \
    "$output/taskmgr-rs_${version}_${deb_arch}.deb"
else
  echo "dpkg-deb unavailable; DEB generation skipped" >&2
fi

if command -v rpmbuild >/dev/null 2>&1; then
  rpm_top="$stage_root/rpmbuild"
  rpm_output="$stage_root/rpm-output"
  mkdir -p "$rpm_top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} "$rpm_output"
  rpmbuild -bb "$repo_root/packaging/linux/taskmgr-rs.spec" \
    --define "_topdir $rpm_top" \
    --define "_rpmdir $rpm_output" \
    --define "package_version $version" \
    --define "bundle_dir $bundle" \
    --define "helper_path $helper" \
    --define "launcher_path $repo_root/packaging/linux/taskmgr_rs-launcher" \
    --define "desktop_path $repo_root/packaging/linux/io.github.jameslinyj.taskmgr_rs.desktop" \
    --define "policy_path $repo_root/packaging/linux/io.github.jameslinyj.taskmgr_rs.policy" \
    --define "icons_path $repo_root/packaging/linux/icons/hicolor" \
    --define "license_path $repo_root/LICENSE"
  while IFS= read -r -d '' rpm; do
    install -m0644 "$rpm" "$output/$(basename "$rpm")"
  done < <(find "$rpm_output" -type f -name '*.rpm' -print0)
else
  echo "rpmbuild unavailable; RPM generation skipped" >&2
fi

(
  cd "$output"
  find . -maxdepth 1 -type f \
    \( -name '*.tar.gz' -o -name '*.deb' -o -name '*.rpm' \) \
    -printf '%f\0' \
    | sort -z \
    | xargs -0 -r sha256sum > SHA256SUMS
  sha256sum --check SHA256SUMS
)

echo "Linux packages written to $output"
