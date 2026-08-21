#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - GitHub Release 资产汇总与校验
#
#   文件:       scripts/prepare-release-assets.sh
#
#   日期:       2026年08月21日
#   环境:       GitHub-hosted Ubuntu 24.04 x64；Bash 5；GNU coreutils
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   GitHub Actions artifact contract；SHA-256
# --------------------------------------------------------------------------

set -euo pipefail
export LC_ALL=C

if [[ $# -ne 3 ]]; then
  echo 'usage: prepare-release-assets.sh <artifact-root> <output-directory> <version>' >&2
  exit 2
fi

artifact_root=$(realpath -- "$1")
output_argument=$2
version=$3

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid package version: $version" >&2
  exit 1
fi
if [[ ! -d "$artifact_root" || -L "$artifact_root" ]]; then
  echo "artifact root is not a regular directory: $artifact_root" >&2
  exit 1
fi

if [[ -e "$output_argument" ]]; then
  if [[ ! -d "$output_argument" || -L "$output_argument" ]]; then
    echo "release output is not a regular directory: $output_argument" >&2
    exit 1
  fi
  if find "$output_argument" -mindepth 1 -print -quit | grep -q .; then
    echo "release output must be empty: $output_argument" >&2
    exit 1
  fi
else
  mkdir -p -- "$output_argument"
fi
output_root=$(realpath -- "$output_argument")

case "$output_root/" in
  "$artifact_root/" | "$artifact_root/"*)
    echo 'release output must not be inside the downloaded artifact tree' >&2
    exit 1
    ;;
esac

require_artifact_directory() {
  local directory=$1
  local expected_entry_count=$2
  local -a entries=()

  if [[ ! -d "$directory" || -L "$directory" ]]; then
    echo "required artifact directory is missing: $directory" >&2
    exit 1
  fi
  mapfile -d '' entries < <(find "$directory" -mindepth 1 -maxdepth 1 -print0)
  if [[ ${#entries[@]} -ne $expected_entry_count ]]; then
    echo "unexpected file count in $directory: expected $expected_entry_count, received ${#entries[@]}" >&2
    exit 1
  fi
  for entry in "${entries[@]}"; do
    if [[ ! -f "$entry" || -L "$entry" ]]; then
      echo "artifact entry is not a regular file: $entry" >&2
      exit 1
    fi
  done
}

find_single_file() {
  local directory=$1
  local pattern=$2
  local -a matches=()

  mapfile -d '' matches < <(
    find "$directory" -maxdepth 1 -type f ! -type l -name "$pattern" -print0
  )
  if [[ ${#matches[@]} -ne 1 ]]; then
    echo "expected exactly one $pattern in $directory, received ${#matches[@]}" >&2
    exit 1
  fi
  basename -- "${matches[0]}"
}

verify_checksum_manifest() {
  local directory=$1
  local manifest_name=$2
  shift 2
  local -a expected_files=("$@")
  local -a manifest_files=()
  local -a manifest_digests=()
  local line digest filename remainder expected_file actual_digest declared_digest index
  local expected_listing actual_listing

  if [[ ! -f "$directory/$manifest_name" || -L "$directory/$manifest_name" ]]; then
    echo "checksum manifest is missing: $directory/$manifest_name" >&2
    exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    read -r digest filename remainder <<< "$line"
    if [[ ! "$digest" =~ ^[0-9a-fA-F]{64}$ || -z "${filename:-}" || -n "${remainder:-}" ]]; then
      echo "malformed checksum manifest: $directory/$manifest_name" >&2
      exit 1
    fi
    manifest_files+=("${filename#\*}")
    manifest_digests+=("${digest,,}")
  done < "$directory/$manifest_name"

  expected_listing=$(printf '%s\n' "${expected_files[@]}" | sort)
  actual_listing=$(printf '%s\n' "${manifest_files[@]}" | sort)
  if [[ "$actual_listing" != "$expected_listing" ]]; then
    echo "checksum manifest lists unexpected files: $directory/$manifest_name" >&2
    exit 1
  fi
  for expected_file in "${expected_files[@]}"; do
    declared_digest=
    for index in "${!manifest_files[@]}"; do
      if [[ "${manifest_files[$index]}" == "$expected_file" ]]; then
        declared_digest=${manifest_digests[$index]}
        break
      fi
    done
    if [[ -z "$declared_digest" ]]; then
      echo "checksum is missing for $expected_file" >&2
      exit 1
    fi
    actual_digest=$(sha256sum -- "$directory/$expected_file")
    actual_digest=${actual_digest%% *}
    if [[ "$actual_digest" != "$declared_digest" ]]; then
      echo "checksum mismatch for $directory/$expected_file" >&2
      exit 1
    fi
  done
}

copy_asset() {
  local directory=$1
  local filename=$2
  local destination=$output_root/$filename

  if [[ ! -f "$directory/$filename" || -L "$directory/$filename" ]]; then
    echo "release asset is missing: $directory/$filename" >&2
    exit 1
  fi
  if [[ -e "$destination" ]]; then
    echo "duplicate release asset name: $filename" >&2
    exit 1
  fi
  install -m 0644 -- "$directory/$filename" "$destination"
}

for architecture in x64 arm64; do
  linux_directory="$artifact_root/taskmgr-rs-linux-$architecture-packages"
  require_artifact_directory "$linux_directory" 4
  if [[ "$architecture" == x64 ]]; then
    debian_architecture=amd64
    rpm_architecture=x86_64
  else
    debian_architecture=arm64
    rpm_architecture=aarch64
  fi
  linux_archive="taskmgr-rs-$version-linux-$architecture.tar.gz"
  debian_package="taskmgr-rs_${version}_${debian_architecture}.deb"
  rpm_package=$(find_single_file \
    "$linux_directory" \
    "taskmgr-rs-$version-*.$rpm_architecture.rpm")
  linux_files=("$linux_archive" "$debian_package" "$rpm_package")
  verify_checksum_manifest "$linux_directory" SHA256SUMS "${linux_files[@]}"
  for filename in "${linux_files[@]}"; do
    copy_asset "$linux_directory" "$filename"
  done
done

for architecture in x64 arm64; do
  windows_directory="$artifact_root/taskmgr-rs-windows-$architecture-packages"
  require_artifact_directory "$windows_directory" 3
  windows_archive="taskmgr-rs-$version-windows-$architecture.zip"
  windows_installer="taskmgr-rs-$version-windows-$architecture-setup-unsigned.exe"
  windows_manifest="SHA256SUMS-windows-$architecture"
  windows_files=("$windows_archive" "$windows_installer")
  verify_checksum_manifest \
    "$windows_directory" \
    "$windows_manifest" \
    "${windows_files[@]}"
  for filename in "${windows_files[@]}"; do
    copy_asset "$windows_directory" "$filename"
  done
done

mapfile -d '' release_files < <(
  find "$output_root" -mindepth 1 -maxdepth 1 -type f ! -type l -print0
)
if [[ ${#release_files[@]} -ne 10 ]]; then
  echo "expected ten release packages, received ${#release_files[@]}" >&2
  exit 1
fi

(
  cd -- "$output_root"
  find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\0' \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
  sha256sum --strict --check SHA256SUMS
)

echo "Release assets prepared in $output_root"
