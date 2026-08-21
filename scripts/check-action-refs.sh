#!/usr/bin/env bash
# Every `owner/repo@vN` reference in the skills must exist and be the current
# major. Four skills independently drifted to actions/checkout at v4, v5, v6 and
# v7 simultaneously, so a customer reading two skills got two different answers.
# Nothing caught it because each reference was individually plausible.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required" >&2
  exit 1
fi

# Deliberate exceptions: references that must NOT be bumped.
# tj-actions/changed-files@v45 is the CVE-2025-30066 example in the security
# skill. Pointing it at a current version would destroy the point.
# OWNER/REPO is a documentation placeholder, not a real reference.
is_exempt() {
  case "$1" in
    tj-actions/changed-files) return 0 ;;
    OWNER/REPO|owner/repo) return 0 ;;
    *) return 1 ;;
  esac
}

refs=$(python3 - <<'PY'
import re, pathlib
pat = re.compile(r'(?:^|[^A-Za-z0-9_./-])([A-Za-z0-9][\w.-]*/[A-Za-z0-9][\w.-]*)@(v\d+)\b')
found = set()
for p in pathlib.Path("skills").rglob("*.md"):
    for repo, ver in pat.findall(p.read_text()):
        found.add(f"{repo}@{ver}")
print("\n".join(sorted(found)))
PY
)

if [ -z "$refs" ]; then
  echo "no versioned action references found" >&2
  exit 1
fi

fail=0
count=0
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  repo=${ref%@*}
  ver=${ref#*@}
  count=$((count + 1))

  if is_exempt "$repo"; then
    printf 'skip  %-42s (documented exception)\n' "$ref"
    continue
  fi

  if ! tags=$(gh api "repos/$repo/tags" --paginate --jq '.[].name' 2>/dev/null); then
    printf 'FAIL  %-42s repository does not exist or is unreadable\n' "$ref"
    fail=1
    continue
  fi

  current=$(printf '%s\n' "$tags" | grep -E '^v[0-9]+$' | sort -Vr | head -1 || true)
  if [ -z "$current" ]; then
    printf 'skip  %-42s (no floating major tag upstream)\n' "$ref"
    continue
  fi

  if [ "$ver" = "$current" ]; then
    printf 'ok    %-42s %s\n' "$ref" "$current"
  else
    printf 'FAIL  %-42s current major is %s\n' "$ref" "$current"
    fail=1
  fi
done <<<"$refs"

echo
if [ "$fail" -ne 0 ]; then
  echo "action references are stale or invalid; bump them or add a documented exception" >&2
  exit 1
fi
echo "all $count action references exist and are current"
