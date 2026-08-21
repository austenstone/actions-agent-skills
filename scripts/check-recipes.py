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

    if failures:
        print(f"{failures} bad recipe(s) in documented code blocks")
        return 1

    print(f"scanned {scanned} markdown files")
    print("documented shell recipes pass all 3 regression guards")
    return 0


if __name__ == "__main__":
    sys.exit(main())
