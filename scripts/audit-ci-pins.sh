#!/usr/bin/env bash
# +-------------------------------------------------------------------------
#
#   taskmgr-rs - 持续集成不可变依赖审计
#
#   文件:       scripts/audit-ci-pins.sh
#
#   日期:       2026年08月21日
#   环境:       Fedora Linux 46 x86_64；Bash；GitHub Actions YAML
#   作者:       JamesLinYJ
#   协助:       OpenAI Codex:gpt-5.6-sol
#   参考标准:   GitHub Actions secure use；Git object IDs
# --------------------------------------------------------------------------

set -euo pipefail

readonly workflow_directory='.github/workflows'
readonly flutter_revision='6655482ec06e547f90abf8ae7590466f4415978d'
readonly flutter_tag='3.47.1'
readonly inno_setup_version='6.7.3'
readonly inno_setup_sha256='9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732'
readonly inno_setup_signer_thumbprint='e0ab19c8d38cbf9c44709925122a7a02f8c70cb7'
readonly inno_setup_url='https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe'

failures=0
external_action_count=0
flutter_revision_count=0
flutter_tag_count=0
matched_line=0
shopt -s nullglob
workflow_files=("$workflow_directory"/*.yml "$workflow_directory"/*.yaml)

require_single_workflow_line() {
  local description="$1"
  local pattern="$2"
  local matches
  local count

  matches="$(grep -nE "$pattern" .github/workflows/ci.yml || true)"
  count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
  if ((count != 1)); then
    echo "Expected exactly one executable $description line, found $count." >&2
    failures=1
    matched_line=0
    return
  fi
  matched_line="${matches%%:*}"
}

require_single_trimmed_workflow_line() {
  local description="$1"
  local expected="$2"
  local line
  local trimmed
  local line_number=0
  local count=0
  local found_line=0

  while IFS= read -r line; do
    ((line_number += 1))
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [[ "$trimmed" == "$expected" ]]; then
      ((count += 1))
      found_line=$line_number
    fi
  done < .github/workflows/ci.yml

  if ((count != 1)); then
    echo "Expected exactly one executable $description line, found $count." >&2
    failures=1
    matched_line=0
    return
  fi
  matched_line=$found_line
}

while IFS=: read -r file line_number declaration; do
  reference="${declaration#*uses:}"
  reference="${reference%%#*}"
  reference="${reference#"${reference%%[![:space:]]*}"}"
  reference="${reference%"${reference##*[![:space:]]}"}"

  if [[ "$reference" == ./* ]]; then
    continue
  fi
  ((external_action_count += 1))
  if [[ ! "$reference" =~ ^[^@[:space:]]+@[0-9a-f]{40}$ ]]; then
    echo "$file:$line_number: external action is not pinned to a full commit SHA: $reference" >&2
    failures=1
  fi
done < <(grep -nH -E '^[[:space:]]*(-[[:space:]]+)?uses:' "${workflow_files[@]}" || true)

if ((external_action_count == 0)); then
  echo 'No external GitHub Actions references were found to audit.' >&2
  failures=1
fi

while IFS=: read -r file line_number declaration; do
  ((flutter_revision_count += 1))
  revision="${declaration#*FLUTTER_GIT_REVISION:}"
  revision="${revision#"${revision%%[![:space:]]*}"}"
  revision="${revision%"${revision##*[![:space:]]}"}"
  if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
    echo "$file:$line_number: Flutter Git revision is not a full commit SHA: $revision" >&2
    failures=1
  elif [[ "$revision" != "$flutter_revision" ]]; then
    echo "$file:$line_number: Flutter Git revision differs from the reviewed 3.47.1 commit" >&2
    failures=1
  fi
done < <(grep -nH -E '^[[:space:]]+FLUTTER_GIT_REVISION:' "${workflow_files[@]}" || true)

if ((flutter_revision_count != 5)); then
  echo "Expected five verified Flutter revision declarations, found $flutter_revision_count." >&2
  failures=1
fi

while IFS=: read -r file line_number declaration; do
  ((flutter_tag_count += 1))
  tag="${declaration#*FLUTTER_GIT_TAG:}"
  tag="${tag#"${tag%%[![:space:]]*}"}"
  tag="${tag%"${tag##*[![:space:]]}"}"
  if [[ "$tag" != "$flutter_tag" ]]; then
    echo "$file:$line_number: Flutter Git tag differs from the reviewed release tag" >&2
    failures=1
  fi
done < <(grep -nH -E '^[[:space:]]+FLUTTER_GIT_TAG:' "${workflow_files[@]}" || true)

if ((flutter_tag_count != 2)); then
  echo "Expected two verified ARM64 Flutter tag declarations, found $flutter_tag_count." >&2
  failures=1
fi

if grep -nH -E 'git (clone|fetch|checkout).*(--branch[[:space:]]+)?[0-9]+\.[0-9]+\.[0-9]+' \
  "${workflow_files[@]}"; then
  echo 'Flutter Git bootstrap must fetch an immutable commit, not a release tag.' >&2
  failures=1
fi

if ! grep -qF 'fetch --depth 1 origin "$FLUTTER_GIT_REVISION"' .github/workflows/ci.yml; then
  echo 'Linux ARM64 Flutter bootstrap does not fetch the reviewed commit.' >&2
  failures=1
fi
if ! grep -qF 'fetch --depth 1 origin $env:FLUTTER_GIT_REVISION' .github/workflows/ci.yml; then
  echo 'Windows ARM64 Flutter bootstrap does not fetch the reviewed commit.' >&2
  failures=1
fi
if ! grep -qF '"refs/tags/$FLUTTER_GIT_TAG:refs/tags/$FLUTTER_GIT_TAG"' .github/workflows/ci.yml; then
  echo 'Linux ARM64 Flutter bootstrap does not hydrate the verified release tag.' >&2
  failures=1
fi
if ! grep -qF 'git -C $flutterRoot fetch --depth 1 --no-tags origin "$($tagRef):$($tagRef)"' .github/workflows/ci.yml; then
  echo 'Windows ARM64 Flutter bootstrap does not hydrate the verified release tag.' >&2
  failures=1
fi
if grep -nH -E '^[[:space:]]+cache:[[:space:]]+true([[:space:]]|$)' "${workflow_files[@]}"; then
  echo 'Flutter Action caching is disabled because the pinned composite action delegates cache work through a mutable nested action reference.' >&2
  failures=1
fi

if grep -niH -E '^[[:space:]]*([^#].*)?choco(latey)?([.]exe)?[^#]*innosetup' \
  "${workflow_files[@]}"; then
  echo 'Inno Setup must not be installed from a mutable package-manager feed.' >&2
  failures=1
fi

require_single_workflow_line \
  'reviewed Inno Setup version declaration' \
  "^[[:space:]]+INNO_SETUP_VERSION:[[:space:]]+'${inno_setup_version//./\\.}'[[:space:]]*$"
require_single_workflow_line \
  'reviewed Inno Setup SHA-256 declaration' \
  "^[[:space:]]+INNO_SETUP_SHA256:[[:space:]]+$inno_setup_sha256[[:space:]]*$"
require_single_workflow_line \
  'reviewed Inno Setup signer certificate declaration' \
  "^[[:space:]]+INNO_SETUP_SIGNER_THUMBPRINT:[[:space:]]+$inno_setup_signer_thumbprint[[:space:]]*$"
require_single_workflow_line \
  'immutable Inno Setup download declaration' \
  "^[[:space:]]+INNO_SETUP_URL:[[:space:]]+$inno_setup_url[[:space:]]*$"

require_single_workflow_line \
  'Inno Setup download' \
  '^[[:space:]]+Invoke-WebRequest[[:space:]]+-Uri[[:space:]]+\$env:INNO_SETUP_URL[[:space:]]+-OutFile[[:space:]]+\$installerPath[[:space:]]*$'
inno_download_line=$matched_line
require_single_workflow_line \
  'Inno Setup SHA-256 calculation' \
  '^[[:space:]]+\$actualHash[[:space:]]*=[[:space:]]*\(Get-FileHash[[:space:]]+-LiteralPath[[:space:]]+\$installerPath[[:space:]]+-Algorithm[[:space:]]+SHA256\)\.Hash[[:space:]]*$'
inno_hash_line=$matched_line
require_single_trimmed_workflow_line \
  'Inno Setup case-insensitive hash comparison' \
  'if (-not $actualHash.Equals($env:INNO_SETUP_SHA256, [System.StringComparison]::OrdinalIgnoreCase)) {'
inno_hash_compare_line=$matched_line
require_single_trimmed_workflow_line \
  'fail-closed Inno Setup hash rejection' \
  'throw "Inno Setup SHA-256 mismatch: expected $env:INNO_SETUP_SHA256, received $actualHash"'
inno_hash_throw_line=$matched_line
require_single_trimmed_workflow_line \
  'Authenticode signature acquisition' \
  '$signature = Get-AuthenticodeSignature -LiteralPath $Path'
inno_signature_acquire_line=$matched_line
require_single_trimmed_workflow_line \
  'valid Authenticode status check' \
  'if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {'
inno_signature_status_line=$matched_line
require_single_trimmed_workflow_line \
  'fail-closed Authenticode status rejection' \
  'throw "Invalid Authenticode signature for $Path`: $($signature.Status)"'
inno_signature_throw_line=$matched_line
require_single_trimmed_workflow_line \
  'Authenticode certificate subject acquisition' \
  '$subject = $signature.SignerCertificate.Subject'
inno_subject_acquire_line=$matched_line
require_single_trimmed_workflow_line \
  'exact Pyrsys certificate subject check' \
  "if (\$subject -ne 'CN=Pyrsys B.V., O=Pyrsys B.V., S=Noord-Holland, C=NL') {"
inno_subject_check_line=$matched_line
require_single_trimmed_workflow_line \
  'fail-closed publisher rejection' \
  'throw "Unexpected Inno Setup publisher: $subject"'
inno_subject_throw_line=$matched_line
require_single_trimmed_workflow_line \
  'Authenticode signer thumbprint acquisition' \
  '$thumbprint = $signature.SignerCertificate.Thumbprint'
inno_thumbprint_acquire_line=$matched_line
require_single_trimmed_workflow_line \
  'exact signer thumbprint check' \
  'if (-not $thumbprint.Equals($env:INNO_SETUP_SIGNER_THUMBPRINT, [System.StringComparison]::OrdinalIgnoreCase)) {'
inno_thumbprint_check_line=$matched_line
require_single_trimmed_workflow_line \
  'fail-closed signer thumbprint rejection' \
  'throw "Unexpected Inno Setup signer certificate: $thumbprint"'
inno_thumbprint_throw_line=$matched_line
require_single_workflow_line \
  'Inno Setup installer signature verification' \
  '^[[:space:]]+Assert-PyrsysSignature[[:space:]]+-Path[[:space:]]+\$installerPath[[:space:]]*$'
inno_installer_signature_line=$matched_line
require_single_workflow_line \
  'Inno Setup installer execution' \
  '^[[:space:]]+\$installer[[:space:]]*=[[:space:]]*Start-Process[[:space:]]+-FilePath[[:space:]]+\$installerPath([[:space:]]+.*)?$'
inno_install_line=$matched_line
require_single_workflow_line \
  'Inno Setup compiler signature verification' \
  '^[[:space:]]+Assert-PyrsysSignature[[:space:]]+-Path[[:space:]]+\$compilerPath[[:space:]]*$'
inno_compiler_signature_line=$matched_line
require_single_workflow_line \
  'verified Inno Setup compiler export' \
  '^[[:space:]]+Add-Content[[:space:]]+-LiteralPath[[:space:]]+\$env:GITHUB_ENV[[:space:]]+-Value[[:space:]]+"INNO_SETUP_COMPILER=\$compilerPath"[[:space:]]*$'
inno_export_line=$matched_line
require_single_workflow_line \
  'verified Inno Setup compiler package argument' \
  '^[[:space:]]+-InnoCompiler[[:space:]]+\$env:INNO_SETUP_COMPILER([[:space:]]+.*)?$'
inno_package_line=$matched_line

if ! ((inno_signature_acquire_line < inno_signature_status_line &&
       inno_signature_status_line < inno_signature_throw_line &&
       inno_signature_throw_line < inno_subject_acquire_line &&
       inno_subject_acquire_line < inno_subject_check_line &&
       inno_subject_check_line < inno_subject_throw_line &&
       inno_subject_throw_line < inno_thumbprint_acquire_line &&
       inno_thumbprint_acquire_line < inno_thumbprint_check_line &&
       inno_thumbprint_check_line < inno_thumbprint_throw_line &&
       inno_download_line < inno_hash_line &&
       inno_hash_line < inno_hash_compare_line &&
       inno_hash_compare_line < inno_hash_throw_line &&
       inno_hash_throw_line < inno_installer_signature_line &&
       inno_installer_signature_line < inno_install_line &&
       inno_install_line < inno_compiler_signature_line &&
       inno_compiler_signature_line < inno_export_line &&
       inno_export_line < inno_package_line)); then
  echo 'Verified Inno Setup steps are absent or no longer ordered before package compilation.' >&2
  failures=1
fi

if ((failures != 0)); then
  exit 1
fi

echo 'CI dependency references are immutable.'
