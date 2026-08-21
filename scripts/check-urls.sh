#!/usr/bin/env bash
# Verify every external URL cited in the skills still resolves.
#
# The skills deliberately link live documentation instead of copying numbers
# into markdown. That only works if the links are good, so this runs in CI.
set -euo pipefail

cd "$(dirname "${0}")/.."

# Hosts that return 403 to non-browser clients. The URL is fine; their bot
# protection is not. Skipping is better than a permanently red check.
BOT_BLOCKED='^https://(www\.)?npmjs\.com/'

urls="$(mktemp)"
bad="$(mktemp)"
trap 'rm -f "${urls}" "${bad}"' EXIT

grep -rhoE 'https://[^ )>"`]+' --include='*.md' . |
  sed 's/[.,;:]*$//' |
  sort -u |
  grep -vE "${BOT_BLOCKED}" >"${urls}"

echo "checking $(wc -l <"${urls}" | tr -d ' ') unique URLs"

check_url() {
  local url="${1}" code
  code="$(curl -sS -o /dev/null -w '%{http_code}' -L --max-time 20 "${url}" 2>/dev/null || echo 000)"
  case "${code}" in
    2* | 3*) ;;
    *) echo "${code}  ${url}" ;;
  esac
}
export -f check_url

xargs -P 12 -I{} bash -c 'check_url "$@"' _ {} <"${urls}" >"${bad}"

if [[ -s "${bad}" ]]; then
  echo
  echo "unreachable:"
  cat "${bad}"
  echo
  echo "Fix or replace these. A dead citation is worse than no citation."
  exit 1
fi

echo "all URLs resolve"
