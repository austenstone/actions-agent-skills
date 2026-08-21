#!/usr/bin/env python3
"""Validate SKILL.md frontmatter.

Two skills shipped with frontmatter that did not parse, because an unquoted
description contained ``secrets: inherit``. YAML read that as a nested mapping
key and the whole skill failed to load. Nothing caught it, so this exists.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

ALLOWED_KEYS = {"name", "description"}
MAX_DESCRIPTION = 1024
FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)

skills = sorted(Path("skills").glob("*/SKILL.md"))
if not skills:
    sys.exit("no skills found; run from the repo root")

failures: list[str] = []

for path in skills:
    slug = path.parent.name
    match = FRONTMATTER.match(path.read_text())
    if not match:
        failures.append(f"{slug}: no frontmatter block")
        continue

    try:
        meta = yaml.safe_load(match.group(1))
    except yaml.YAMLError as exc:
        detail = str(exc).splitlines()[0]
        failures.append(
            f"{slug}: frontmatter is not valid YAML ({detail}). "
            "An unquoted value containing ': ' is the usual cause; quote it."
        )
        continue

    if not isinstance(meta, dict):
        failures.append(f"{slug}: frontmatter is not a mapping")
        continue

    problems = []
    extra = set(meta) - ALLOWED_KEYS
    if extra:
        problems.append(f"unsupported keys {sorted(extra)}")
    if meta.get("name") != slug:
        problems.append(f"name {meta.get('name')!r} does not match directory {slug!r}")

    description = meta.get("description")
    if not isinstance(description, str) or not description.strip():
        problems.append("missing description")
    else:
        if "Use when" not in description:
            problems.append("description has no 'Use when:' trigger list")
        if len(description) > MAX_DESCRIPTION:
            problems.append(f"description is {len(description)} chars (max {MAX_DESCRIPTION})")

    if problems:
        failures.extend(f"{slug}: {p}" for p in problems)
    else:
        print(f"ok    {slug:<30} description {len(description)} chars")

if failures:
    print("\nfrontmatter problems:", file=sys.stderr)
    for f in failures:
        print(f"  {f}", file=sys.stderr)
    sys.exit(1)

print(f"\nall {len(skills)} skills have valid, loadable frontmatter")
