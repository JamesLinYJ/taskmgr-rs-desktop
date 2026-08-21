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
readonly flutter_revision='84fc5cbb223bc12f83d65b647ff8a56caf779ffd'

failures=0
external_action_count=0
flutter_revision_count=0
shopt -s nullglob
workflow_files=("$workflow_directory"/*.yml "$workflow_directory"/*.yaml)

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
    echo "$file:$line_number: Flutter Git revision differs from the reviewed 3.44.7 commit" >&2
    failures=1
  fi
done < <(grep -nH -E '^[[:space:]]+FLUTTER_GIT_REVISION:' "${workflow_files[@]}" || true)

if ((flutter_revision_count != 5)); then
  echo "Expected five verified Flutter revision declarations, found $flutter_revision_count." >&2
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
if grep -nH -E '^[[:space:]]+cache:[[:space:]]+true([[:space:]]|$)' "${workflow_files[@]}"; then
  echo 'Flutter Action caching is disabled because the pinned composite action delegates cache work through a mutable nested action reference.' >&2
  failures=1
fi

if ((failures != 0)); then
  exit 1
fi

echo 'CI dependency references are immutable.'
