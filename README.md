# Actions Agent Skills

Agent skills that read GitHub Actions workflows and make them **safer, faster, and better-shaped** — backed by real linters instead of vibes.

Drop-in for any agent that reads `SKILL.md` files: GitHub Copilot CLI, Claude Code, Cursor, or anything following the [Agent Skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) convention.

## Why this exists

Most workflow-review guidance for agents is prose: "avoid template injection", "pin your actions". The agent then greps the YAML and reasons about it. That misses things, and worse, it produces confident findings nobody can verify.

These skills do the opposite. They **run [`actionlint`](https://github.com/rhysd/actionlint) and [`zizmor`](https://docs.zizmor.sh/)**, parse the JSON, and rank what comes back. Every claim traces to a rule ident or a live documentation URL.

The difference is measurable. From [`test-corpus/`](test-corpus/):

| fixture | `actionlint` | `zizmor` |
|---|---|---|
| `broken.yml` — correctness bugs | **7 findings** | 0 relevant |
| `insecure.yml` — security bugs | 3 | **14 findings, 8 rules** |
| `clean.yml` — well-written | **0** | **0** |

Neither tool subsumes the other, and neither is replaceable by reading the file. A cron hour of `25`, a typo'd `ubuntu-lastest` label, a `needs:` pointing at a job that doesn't exist, `tj-actions/changed-files@v35` carrying a known CVE — these are not things an LLM reliably spots by looking.

## The other principle: link, don't freeze

Every number in the GitHub docs is a number that will be wrong in six months. So these skills carry **procedure, decision logic, and a question → URL routing table** — not a copy of the docs.

[`docs-map.md`](skills/actions-workflow-toolkit/references/docs-map.md) is the core of this: ~40 rows mapping "what am I trying to find out" to the canonical URL. The agent fetches live truth instead of trusting stale markdown.

CI enforces it. Every external URL is checked on every push.

## Skills

```
actions-workflow-toolkit          shared substrate — the other three load it
├── actions-security-review       zizmor-driven; injection, triggers, pinning, permissions
├── actions-optimization          measure first; queue vs run vs rerun, then the right lever
└── actions-architecture-review   the shape problems no linter can see
```

| Skill | Use when |
|---|---|
| [`actions-workflow-toolkit`](skills/actions-workflow-toolkit/SKILL.md) | Always, alongside one of the others. Tool invocations, JSON shapes, performance-data ladder, safety contract. |
| [`actions-security-review`](skills/actions-security-review/SKILL.md) | "Is this workflow safe?", "audit our Actions security", pinning, `pull_request_target`, secrets exposure. |
| [`actions-optimization`](skills/actions-optimization/SKILL.md) | "CI is slow", "reduce our Actions bill", cache misses, runner sizing, matrix tuning. |
| [`actions-architecture-review`](skills/actions-architecture-review/SKILL.md) | "Reusable workflow or composite action?", duplicated CI across repos, monorepo design, workflow governance. |

`actions-architecture-review` is the one with no linter behind it — deliberately. Linters work per-file and cannot tell you that 23 repos copy-pasted the same deploy job.

## Install

The tools:

```bash
brew install actionlint          # or: go install github.com/rhysd/actionlint/cmd/actionlint@latest
brew install zizmor              # or: uv tool install zizmor / cargo install zizmor
```

The skills — clone anywhere your agent reads skills from:

```bash
git clone https://github.com/austenstone/actions-agent-skills
cp -r actions-agent-skills/skills/* ~/.copilot/skills/
```

`zizmor` wants `GH_TOKEN` for its network audits (known-CVE lookups, impostor-commit detection, remote repo auditing). Without it, use `--no-online-audits`.

## Try it

No clone required — `zizmor` audits any public repo by slug:

```bash
GH_TOKEN=$(gh auth token) zizmor --format json actions/checkout | jq -r \
  '.[] | "\(.determinations.severity)\t\(.ident)\tline \(.locations[0].concrete.location.start_point.row + 1)"'
```

> `start_point.row` is **0-indexed**. Add 1 before showing a human a line number.

## Safety

The skills operate read-only by default. They will not commit, push, or apply fixes unless you explicitly ask. `zizmor --fix` is experimental and workflows are production infrastructure, so the default is to propose a diff and let you decide.

Full contract: [`actions-workflow-toolkit/SKILL.md`](skills/actions-workflow-toolkit/SKILL.md#safety-contract).

## Development

```bash
./test-corpus/verify.sh            # fixtures still produce the documented findings
./scripts/check-urls.sh            # every cited URL resolves
./scripts/check-audit-idents.sh    # no invented or stale zizmor rule names
python3 scripts/check-links.py     # every relative link and anchor resolves
python3 scripts/check-frontmatter.py  # skill frontmatter parses and has triggers
```

All four run in CI. The repo also runs `actionlint` and `zizmor` on its own workflows — a security skill whose own CI fails its own review is not worth reading.

## License

MIT. See [LICENSE](LICENSE).
