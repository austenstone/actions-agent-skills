#!/usr/bin/env python3
"""Verify every relative markdown link and heading anchor in the repo resolves.

Broken links are the failure mode for a reference-first skill set: the whole
value proposition is that an agent can follow a pointer instead of trusting
frozen prose. A dead link silently degrades the skill back to guesswork.
"""
import re
import pathlib
import sys

LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HEADING = re.compile(r"^(#{1,6})\s+(.*)")
FENCE = re.compile(r"^\s*```")


def slug(text):
    """Reproduce GitHub's heading-anchor algorithm.

    Punctuation is dropped without collapsing the surrounding whitespace, so
    'Step 3 - Get data' written with an em dash yields a double hyphen.
    Collapsing whitespace here would produce false failures.
    """
    t = text.strip().lower()
    t = re.sub(r"[^\w\s-]", "", t)
    return t.replace(" ", "-")


def anchors(path):
    out, in_fence = set(), False
    for line in path.read_text().splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = HEADING.match(line)
        if m:
            out.add(slug(m.group(2)))
    return out


def main():
    root = pathlib.Path(__file__).resolve().parent.parent
    files = sorted(p for p in root.rglob("*.md") if "node_modules" not in p.parts)
    cache, bad = {}, []

    for f in files:
        for target in LINK.findall(f.read_text()):
            if target.startswith(("http://", "https://", "mailto:", "#!")):
                continue
            filepart, _, anchor = target.partition("#")
            if filepart:
                dest = (f.parent / filepart).resolve()
                if not dest.exists():
                    bad.append(f"{f.relative_to(root)}: missing file -> {target}")
                    continue
            else:
                dest = f.resolve()
            if anchor and dest.suffix == ".md":
                if dest not in cache:
                    cache[dest] = anchors(dest)
                if anchor not in cache[dest]:
                    bad.append(f"{f.relative_to(root)}: bad anchor -> {target}")

    print(f"scanned {len(files)} markdown files")
    if bad:
        print(f"\n{len(bad)} broken link(s):")
        for b in bad:
            print(f"  {b}")
        return 1
    print("all internal links resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
