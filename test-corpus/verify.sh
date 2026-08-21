#!/usr/bin/env bash
# Assert the fixtures still produce the findings documented in README.md.
# Exits non-zero on any drift, so CI catches tool upgrades that change behavior.
set -euo pipefail

cd "$(dirname "${0}")"

need() {
  command -v "${1}" >/dev/null 2>&1 || {
    echo "missing: ${1}" >&2
    exit 127
  }
}
need actionlint
need zizmor
need jq

# Both tools exit non-zero when they find something, which is not an error here.
# Run each once, cache the JSON, and assert against the cache.
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

for f in clean insecure broken; do
  zizmor --format json "${f}.yml" >"${tmp}/${f}.zizmor.json" 2>/dev/null || true
  actionlint -format '{{json .}}' "${f}.yml" >"${tmp}/${f}.actionlint.json" 2>/dev/null || true
  # An empty file means the tool blew up rather than finding nothing.
  for tool in zizmor actionlint; do
    if ! jq -e 'type == "array"' "${tmp}/${f}.${tool}.json" >/dev/null 2>&1; then
      echo "FAIL  ${tool} produced no parseable JSON for ${f}.yml" >&2
      exit 1
    fi
  done
done

failures=0

check() {
  local label="${1}" expected="${2}" actual="${3}"
  if [[ "${expected}" == "${actual}" ]]; then
    printf 'ok    %-42s %s\n' "${label}" "${actual}"
  else
    printf 'FAIL  %-42s expected %s, got %s\n' "${label}" "${expected}" "${actual}"
    failures=$((failures + 1))
  fi
}

check_present() {
  local label="${1}" needle="${2}" file="${3}" query="${4}"
  if jq -r "${query}" "${file}" | grep -qx "${needle}"; then
    printf 'ok    %-42s present\n' "${label}"
  else
    printf 'FAIL  %-42s missing\n' "${label}"
    failures=$((failures + 1))
  fi
}

echo "== clean.yml : the false-positive control =="
check "clean.yml zizmor findings" 0 "$(jq 'length' "${tmp}/clean.zizmor.json")"
check "clean.yml actionlint findings" 0 "$(jq 'length' "${tmp}/clean.actionlint.json")"

echo
echo "== insecure.yml : security plane =="
check "insecure.yml zizmor findings" 14 "$(jq 'length' "${tmp}/insecure.zizmor.json")"
check "insecure.yml zizmor unique rules" 8 \
  "$(jq -r '[.[].ident] | unique | length' "${tmp}/insecure.zizmor.json")"

for rule in artipacked dangerous-triggers excessive-permissions github-env \
  known-vulnerable-actions secrets-inherit template-injection unpinned-uses; do
  check_present "rule ${rule}" "${rule}" "${tmp}/insecure.zizmor.json" '.[].ident'
done

echo
echo "== broken.yml : correctness plane =="
check "broken.yml actionlint findings" 7 "$(jq 'length' "${tmp}/broken.actionlint.json")"

for kind in events expression job-needs runner-label shellcheck; do
  check_present "kind ${kind}" "${kind}" "${tmp}/broken.actionlint.json" '.[].kind'
done

echo
if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} check(s) failed. Either a fixture drifted or a tool changed behavior."
  echo "If the tool change is legitimate, update test-corpus/README.md and the counts here."
  exit 1
fi
echo "all checks passed"
