#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - GitHub Release 资产汇总测试
#
#   文件:       scripts/test-prepare-release-assets.sh
#
#   日期:       2026年08月21日
#   环境:       Linux x64/ARM64；Bash 5；GNU coreutils
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   项目 GitHub Actions artifact contract；SHA-256
# --------------------------------------------------------------------------

set -euo pipefail

readonly version=0.3.0
readonly temporary_parent=${TMPDIR:-/tmp}
test_root=$(mktemp -d "$temporary_parent/taskmgr-rs-release-test.XXXXXX")
cleanup() {
  case "$test_root" in
    "$temporary_parent"/taskmgr-rs-release-test.*)
      rm -rf -- "$test_root"
      ;;
  esac
}
trap cleanup EXIT INT TERM

artifact_root="$test_root/artifacts"
output_root="$test_root/output"
mkdir -p -- "$artifact_root"

write_fixture() {
  local path=$1
  printf 'release fixture: %s\n' "$(basename -- "$path")" > "$path"
}

write_manifest() {
  local directory=$1
  local manifest=$2
  shift 2
  (
    cd -- "$directory"
    sha256sum -- "$@" > "$manifest"
  )
}

for architecture in x64 arm64; do
  directory="$artifact_root/taskmgr-rs-linux-$architecture-packages"
  mkdir -p -- "$directory"
  if [[ "$architecture" == x64 ]]; then
    debian_architecture=amd64
    rpm_architecture=x86_64
  else
    debian_architecture=arm64
    rpm_architecture=aarch64
  fi
  archive="taskmgr-rs-$version-linux-$architecture.tar.gz"
  debian="taskmgr-rs_${version}_${debian_architecture}.deb"
  rpm="taskmgr-rs-$version-1.$rpm_architecture.rpm"
  for filename in "$archive" "$debian" "$rpm"; do
    write_fixture "$directory/$filename"
  done
  write_manifest "$directory" SHA256SUMS "$archive" "$debian" "$rpm"
done

for architecture in x64 arm64; do
  directory="$artifact_root/taskmgr-rs-windows-$architecture-packages"
  mkdir -p -- "$directory"
  archive="taskmgr-rs-$version-windows-$architecture.zip"
  installer="taskmgr-rs-$version-windows-$architecture-setup-unsigned.exe"
  manifest="SHA256SUMS-windows-$architecture"
  for filename in "$archive" "$installer"; do
    write_fixture "$directory/$filename"
  done
  write_manifest "$directory" "$manifest" "$archive" "$installer"
  sed -i 's/$/\r/' "$directory/$manifest"
done

"$(dirname -- "${BASH_SOURCE[0]}")/prepare-release-assets.sh" \
  "$artifact_root" \
  "$output_root" \
  "$version"

if [[ $(find "$output_root" -mindepth 1 -maxdepth 1 -type f | wc -l) -ne 11 ]]; then
  echo 'release assembly did not produce ten packages and one checksum manifest' >&2
  exit 1
fi
(
  cd -- "$output_root"
  sha256sum --strict --check SHA256SUMS
)

invalid_root="$test_root/invalid-artifacts"
invalid_output="$test_root/invalid-output"
cp -a -- "$artifact_root" "$invalid_root"
write_fixture "$invalid_root/taskmgr-rs-linux-x64-packages/unexpected.bin"
if "$(dirname -- "${BASH_SOURCE[0]}")/prepare-release-assets.sh" \
  "$invalid_root" \
  "$invalid_output" \
  "$version" > /dev/null 2>&1; then
  echo 'release assembly accepted an unexpected artifact file' >&2
  exit 1
fi

corrupt_root="$test_root/corrupt-artifacts"
corrupt_output="$test_root/corrupt-output"
cp -a -- "$artifact_root" "$corrupt_root"
printf 'corrupt\n' >> \
  "$corrupt_root/taskmgr-rs-windows-x64-packages/taskmgr-rs-$version-windows-x64.zip"
if "$(dirname -- "${BASH_SOURCE[0]}")/prepare-release-assets.sh" \
  "$corrupt_root" \
  "$corrupt_output" \
  "$version" > /dev/null 2>&1; then
  echo 'release assembly accepted a checksum mismatch' >&2
  exit 1
fi

echo 'Release asset assembly tests passed.'
