#!/usr/bin/env bash
# Extract the tool wrapper from the toolkit skill and RUN it.
#
# check-recipes.py greps for known-bad shapes. This runs the real thing, which
# is the only way to catch the failure mode that shipped twice: a wrapper that
# reads correctly but aborts or drops findings when actually executed.
#
# Both actionlint and zizmor exit non-zero when they FIND something, which is a
# successful run. Under `set -euo pipefail` an unguarded invocation therefore
# kills the script before its JSON assertion runs. Reading the code does not
# reveal that. Executing it does.
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"
SKILL="skills/actions-workflow-toolkit/SKILL.md"

for tool in actionlint zizmor jq; do
  command -v "$tool" >/dev/null || { echo "SKIP  $tool not installed"; exit 0; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Pull the wrapper verbatim out of the shipped docs. Drop the remote-scan line:
# it needs a token and is covered separately.
python3 - "$REPO/$SKILL" > "$work/wrapper.sh" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
blocks = re.findall(r"```bash\n(.*?)```", text, re.S)
match = [b for b in blocks if "actionlint" in b and "zizmor" in b]
if not match:
    sys.exit("could not find the tool wrapper block in the skill")
for line in match[0].splitlines():
    if "OWNER/REPO" in line:
        continue
    print(line)
PY

mkdir -p "$work/repo/.github/workflows"
cp "$REPO"/test-corpus/*.yml "$work/repo/.github/workflows/"
git -C "$work/repo" init -q .

cd "$work/repo"
# set -euo pipefail is the point of the test: that is what a careful agent writes.
{ echo 'set -euo pipefail'; cat "$work/wrapper.sh"; } > run.sh

if ! bash run.sh 2>run.err; then
  echo "FAIL  the documented wrapper exited non-zero on a normal run"
  echo "      both tools exit non-zero on findings; guard every invocation"
  echo "      with '&& rc=0 || rc=\$?', including the fallback."
  sed 's/^/      /' run.err
  exit 1
fi

fail=0
check_array() {
  jq -e 'type == "array"' "$1" >/dev/null 2>&1 \
    || { echo "FAIL  $1 is not a JSON array — the assertion never ran"; fail=1; }
}
check_array actionlint.json
check_array zizmor.json

# The wrapper must not quietly downgrade to the shellcheck-disabled fallback.
sc=$(jq '[.[] | select(.kind == "shellcheck")] | length' actionlint.json)
if [ "$sc" -eq 0 ]; then
  echo "FAIL  0 shellcheck findings; the corpus has 2"
  echo "      the fallback fired on a run that did not time out, discarding them"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "ok    documented wrapper runs clean under 'set -euo pipefail'"
  echo "ok    actionlint $(jq length actionlint.json) findings, $sc shellcheck retained"
  echo "ok    zizmor $(jq length zizmor.json) findings, valid array"
fi
exit "$fail"
