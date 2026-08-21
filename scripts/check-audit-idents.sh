#!/usr/bin/env bash
# Verify the zizmor audit inventory in the toolkit matches the live audit list.
#
# A skill that names a rule which does not exist is worse than useless: it makes
# the agent confidently cite a fiction. This catches both fabrication and rot
# (audits shipped upstream that the table never picked up).
set -euo pipefail

cd "$(dirname "${0}")/.."

TABLE="skills/actions-workflow-toolkit/references/tools.md"
DOCS="https://docs.zizmor.sh/audits/"

# Backticked tokens inside the audit section that are not audit names.
NOISE='^(url)$'

# Matches both single-word (artipacked) and hyphenated (template-injection)
# idents wrapped in markdown code spans.
# shellcheck disable=SC2016  # backticks are regex literals, not expansions
IDENT_PATTERN='`[a-z][a-z0-9-]{3,}`'

# Structural anchors on the docs page, plus per-audit "-configuration" subsections.
NOT_AN_AUDIT='^(after|before|configuration|audit-rules|remediation|misfeature|github-app|rules[a-z-]*|.*-configuration)$'

live="$(mktemp)"
claimed="$(mktemp)"
trap 'rm -f "${live}" "${claimed}"' EXIT

curl -sS -L --max-time 30 "${DOCS}" |
  grep -oE 'id="[a-z0-9-]+"' |
  sed 's/id="//;s/"//' |
  grep -vE "${NOT_AN_AUDIT}" |
  sort -u >"${live}"

live_count="$(wc -l <"${live}" | tr -d ' ')"
if [[ "${live_count}" -lt 20 ]]; then
  echo "Only ${live_count} audits parsed from ${DOCS}." >&2
  echo "The docs page layout probably changed; update this parser." >&2
  exit 1
fi

# Idents claimed between the audit heading and the next horizontal rule.
# Matches both single-word (artipacked) and hyphenated (template-injection).
sed -n '/^### Audits/,/^---$/p' "${TABLE}" |
  grep -oE "${IDENT_PATTERN}" |
  tr -d '`' |
  grep -vE "${NOISE}" |
  sort -u >"${claimed}"

missing="$(comm -23 "${live}" "${claimed}")"
invented="$(comm -13 "${live}" "${claimed}")"
status=0

if [[ -n "${invented}" ]]; then
  echo "NOT REAL AUDITS (remove or correct these):"
  echo "${invented}" | awk '{print "  " $0}'
  status=1
fi

if [[ -n "${missing}" ]]; then
  echo "NEW AUDITS UPSTREAM (add to the table):"
  echo "${missing}" | awk '{print "  " $0}'
  status=1
fi

if [[ "${status}" -eq 0 ]]; then
  echo "audit inventory matches upstream (${live_count} audits)"
else
  echo
  echo "Source of truth: ${DOCS}"
fi

exit "${status}"
