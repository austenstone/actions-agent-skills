#!/usr/bin/env python3
"""Guard the shell recipes the skills tell agents to run.

Every pattern below already shipped in this repo. None of them produce an
error when they misfire -- they silently delete findings, which is the worst
failure mode for a review tool. All three were caught by running the
documented commands against real repositories, never by reading them.

Only fenced code blocks are checked. Prose that quotes a bad pattern in order
to warn against it is not a defect.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FENCE = re.compile(r"^```")


def code_blocks(text):
    """Yield (line_number, line) for lines inside fenced code blocks."""
    inside = False
    for n, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            inside = not inside
            continue
        if inside:
            yield n, line


def bash_blocks(text):
    """Yield (start_line, [lines]) for each ```bash fenced block."""
    lines = text.splitlines()
    inside = False
    start = 0
    buf = []
    for n, line in enumerate(lines, 1):
        if FENCE.match(line):
            if inside:
                yield start, buf
                buf = []
            inside = line.strip().startswith("```bash")
            start = n + 1
            continue
        if inside:
            buf.append((n, line))


def _strip_literals(line):
    """Remove quoted strings and command substitutions.

    The tool names appear inside echo messages and in output filenames
    (`actionlint.json`); neither is an invocation.
    """
    line = re.sub(r"\$\([^)]*\)", "$X", line)
    line = re.sub(r"'[^']*'", "''", line)
    line = re.sub(r'"[^"]*"', '""', line)
    return line


# The tool name in COMMAND position: start of line or after a separator,
# allowing an `env`/VAR=value prefix.
INVOCATION = re.compile(
    r"(?:^|[;|]|\)\s|\}\s)\s*"
    r"(?:env\s+)?"
    r"(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*"
    r"(?:actionlint|zizmor)\b"
)
# Anything that means the status is being handled rather than allowed to abort.
HANDLED = re.compile(r"rc=\$\?|\|\||&&|^\s*(if|!|for|while|case|#)|\\\s*$")


def check_unguarded(md, text):
    """No bare tool invocation in any fenced block, anywhere.

    Both tools exit non-zero on findings, so a bare invocation aborts the
    script under `set -euo pipefail` -- before whatever validation follows
    it. That applies just as much to a one-line "quick example" as to a
    procedure, because the example is what gets copied. Flag catalogs belong
    in tables, where they cannot be pasted as a script.

    The whole repo satisfies this, so the rule is absolute rather than
    heuristic: any hit is a regression.
    """
    failures = 0
    for _, block in bash_blocks(text):
        for lineno, line in block:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if HANDLED.search(stripped):
                continue
            if not INVOCATION.search(_strip_literals(stripped)):
                continue
            rel = md.relative_to(ROOT)
            print(f"FAIL  {rel}:{lineno}  unguarded invocation in a code block")
            print(f"      {stripped}")
            print(
                "      why: findings exit non-zero (actionlint 1, zizmor "
                "11-14), so this aborts the script under 'set -euo pipefail' "
                "before any assertion that follows it. Either guard it with "
                "'&& rc=0 || rc=$?', or -- if you are listing flags rather "
                "than giving a runnable recipe -- move it into a table so it "
                "cannot be pasted as a script.\n"
            )
            failures += 1
    return failures


CHECKS = [
    (
        re.compile(r"actionlint[^|]*\|\|[^|]*actionlint"),
        "actionlint fallback triggered by a bare '||'",
        "actionlint exits 1 when it FINDS something, so '||' fires on a "
        "successful run and overwrites the shellcheck-enabled result. "
        "Measured: test-corpus 10 findings (2 shellcheck) -> 8 (0 shellcheck). "
        "Branch on the exit code: >=124 is a timeout, 0 and 1 are success.",
    ),
    (
        re.compile(r"zizmor[^|]*(2>\s*/dev/null|\|\s*jq)"),
        "zizmor piped to jq, or its stderr discarded",
        "zizmor writes its fatal to stderr and NOTHING to stdout. jq on empty "
        "input exits 0, so a crashed scan renders as a clean report. Capture "
        "both streams, then assert jq -e 'type == \"array\"'.",
    ),
    (
        re.compile(r"--offline[^\n]*(OWNER/REPO|[a-z0-9_.-]+/[a-z0-9_.-]+\s*$)"),
        "'--offline' used against a remote OWNER/REPO slug",
        "zizmor must fetch a repo before auditing it; --offline always "
        "hard-fails on a slug and upstream's help says to remove the flag. "
        "Only --no-online-audits recovers a remote scan.",
    ),
]


def main():
    failures = 0
    scanned = 0
    for md in sorted(ROOT.glob("skills/**/*.md")):
        text = md.read_text(encoding="utf-8")
        scanned += 1
        for lineno, line in code_blocks(text):
            for pattern, title, why in CHECKS:
                if pattern.search(line):
                    rel = md.relative_to(ROOT)
                    print(f"FAIL  {rel}:{lineno}  {title}")
                    print(f"      {line.strip()}")
                    print(f"      why: {why}\n")
                    failures += 1
        failures += check_unguarded(md, text)

    if failures:
        print(f"{failures} bad recipe(s) in documented code blocks")
        return 1

    print(f"scanned {scanned} markdown files")
    print("documented shell recipes pass all 4 regression guards")
    return 0


if __name__ == "__main__":
    sys.exit(main())
