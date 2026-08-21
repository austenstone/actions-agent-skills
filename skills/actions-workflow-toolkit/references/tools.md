# Tooling Reference

Install commands, invocations, and JSON shapes. **Every shape below was verified by running the tool**, not read from documentation.

## actionlint — correctness

[rhysd/actionlint](https://github.com/rhysd/actionlint) · [check list](https://github.com/rhysd/actionlint/blob/main/docs/checks.md)

### Install

```bash
brew install actionlint shellcheck          # macOS — shellcheck unlocks run: script linting
go install github.com/rhysd/actionlint/cmd/actionlint@latest
bash <(curl -s https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
```

`shellcheck` is optional but strongly recommended — without it you lose shell-script linting inside `run:` blocks, which is a large share of actionlint's value.

### Run

```bash
actionlint -format '{{json .}}' .github/workflows/*.yml   # all findings as one JSON array
actionlint                                                # auto-discovers .github/workflows/
actionlint -shellcheck=                                   # disable shellcheck
actionlint -ignore 'regex matching messages to drop'
actionlint -init-config                                   # write a starter actionlint.yaml
```

Exit codes: `0` clean · `1` findings · `2` fatal.

### Output shape

```json
[{
  "message": "property \"foo\" is not defined in object type {...}",
  "filepath": ".github/workflows/ci.yml",
  "line": 12,
  "column": 18,
  "kind": "expression",
  "snippet": "        run: echo ${{ steps.x.outputs.foo }}\n                       ^~~~~"
}]
```

Useful `kind` values: `syntax-check`, `expression`, `shellcheck`, `matrix`, `events`, `job-needs`, `action`, `workflow-call`, `glob`, `runner-label`, `credentials`.

**Treat every finding as a real bug.** actionlint is conservatively tuned and has a very low false-positive rate. If it says an expression is wrong, it is wrong.

### What it uniquely catches

Expression **type** checking · undefined `needs`/`steps`/`matrix` references · cyclic job dependencies · shellcheck + pyflakes inside `run:` · cron syntax and frequency · glob patterns · IANA timezones · webhook event and payload validation · action input/output validation (fetches `action.yml`) · reusable workflow I/O contracts.

---

## zizmor — security

[zizmorcore/zizmor](https://github.com/zizmorcore/zizmor) · [audit docs](https://docs.zizmor.sh/audits/)

### Install

```bash
brew install zizmor
uv tool install zizmor          # or: pipx install zizmor
cargo install zizmor
```

### Run

```bash
zizmor --format json .github/workflows/           # local
zizmor --format json .github/workflows/ci.yml     # single file
GH_TOKEN=$(gh auth token) zizmor --format json OWNER/REPO        # remote, NO CLONE
GH_TOKEN=$(gh auth token) zizmor --format json OWNER/REPO@v1.2.0 # pinned ref
zizmor --format sarif .github/workflows/          # for code scanning upload
zizmor --offline ...                              # skip all network-dependent audits
```

**Remote mode is the differentiator.** You can audit any repository you can read without cloning it — useful for reviewing a repo you don't have checked out, or auditing a dependency.

Noise control:

```bash
zizmor --min-severity medium --min-confidence medium ...
zizmor --persona regular      # default; auditor = maximum paranoia, pedantic = style too
zizmor --only template-injection,dangerous-triggers ...
```

Exit codes: `0` clean · `1` findings.

### Output shape

```json
[{
  "ident": "template-injection",
  "desc": "code injection via template expansion",
  "determinations": { "severity": "High", "confidence": "High", "persona": "Regular" },
  "url": "https://docs.zizmor.sh/audits/#template-injection",
  "locations": [{
    "symbolic": { "key": {}, "annotation": "this run block", "route": {}, "kind": {}, "feature_kind": {} },
    "concrete": { "location": { "start_point": { "row": 10, "column": 8 } } }
  }],
  "fixes": [{ "title": "pin actions/checkout@v5 to 08c6903c...", "disposition": "safe", "key": {} }]
}]
```

**`concrete.location.start_point.row` is 0-indexed.** Add 1 for a human line number.

### The one jq recipe worth memorizing

```bash
zizmor --format json .github/workflows/ 2>/dev/null | jq -r \
  '.[] | "\(.determinations.severity)\t\(.determinations.confidence)\t\(.ident)\t\(.locations[0].concrete.location.start_point.row + 1)"'
```

```
High	High	template-injection	11
High	High	known-vulnerable-actions	13
High	High	unpinned-uses	10
High	Medium	dangerous-triggers	2
Medium	Medium	excessive-permissions	7
Medium	Low	artipacked	10
```

Severity ∈ `Low|Medium|High|Unknown`. Confidence ∈ `Low|Medium|High`. Rank by severity, then confidence. **Anything `High`/`High` is not a judgment call — fix it.**

### Fixes

`fixes[].title` often contains a **pre-resolved commit SHA** — `"pin actions/checkout@v5 to 08c6903c..."`. Use that string; never resolve or invent a SHA yourself.

`fixes[].disposition`:

- `safe` — semantics preserved. Candidate for auto-apply.
- `unsafe` — may change behavior (e.g. `persist-credentials: false` breaks any later step that pushes). **Propose only.**

```bash
zizmor --fix=safe .github/workflows/       # EXPERIMENTAL — explicit user request only
zizmor --fix=all  .github/workflows/       # includes unsafe. Show the diff first.
```

Always `git diff` after, and re-run `actionlint` — a security fix that breaks syntax is a regression.

### Audits (39 as of v1.29.0)

Grouped for orientation only — the authoritative list and descriptions are at
<https://docs.zizmor.sh/audits/>. Cite the `url` field from the JSON output rather than paraphrasing.

| Group | Audits |
|---|---|
| Injection | `template-injection`, `github-env`, `insecure-commands` |
| Trigger & condition soundness | `dangerous-triggers`, `bot-conditions`, `unsound-condition`, `unsound-contains`, `unsound-ternary` |
| Permissions & secrets | `excessive-permissions`, `undocumented-permissions`, `secrets-inherit`, `overprovisioned-secrets`, `secrets-outside-env`, `unredacted-secrets` |
| Supply chain | `unpinned-uses`, `unpinned-images`, `unpinned-tools`, `known-vulnerable-actions`, `impostor-commit`, `typosquat-uses`, `forbidden-uses`, `stale-action-refs`, `archived-uses`, `ref-confusion`, `ref-version-mismatch`, `adhoc-packages` |
| Credentials | `artipacked`, `hardcoded-container-credentials`, `use-trusted-publishing` |
| Cache & capacity | `cache-poisoning`, `concurrency-limits` |
| Hygiene & config | `self-hosted-runner`, `self-repository`, `obfuscation`, `anonymous-definition`, `insecure-url-scheme`, `superfluous-actions`, `dependabot-cooldown`, `dependabot-execution` |

Several require network access (`known-vulnerable-actions`, `impostor-commit`, `typosquat-uses`, `archived-uses`, `stale-action-refs`, `ref-confusion`). Use `--no-online-audits` to skip only those, or `--offline` to forbid all network use.

`scripts/check-audit-idents.sh` validates every ident named in this repo against the live list, so this table cannot silently rot.

---

## Why these two and nothing else

| Capability | actionlint | zizmor |
|---|---|---|
| YAML schema / unknown keys | ✅ | ❌ |
| Expression **type** checking | ✅ unique | ❌ |
| shellcheck + pyflakes in `run:` | ✅ unique | ❌ |
| Matrix, `needs`, cyclic deps | ✅ unique | ❌ |
| cron / glob / timezone / events | ✅ unique | ❌ |
| Template injection | ✅ | ✅ *(different heuristics — overlap is confirmation)* |
| Dangerous triggers, permissions | ❌ | ✅ unique |
| Unpinned / vulnerable / impostor actions | ❌ | ✅ unique |
| Cache poisoning, `secrets: inherit` | ❌ | ✅ unique |
| Auto-fix | ❌ | ✅ |
| Single binary, JSON, SARIF, offline | ✅ | ✅ |

Near-zero redundancy. Run both.

### Considered and rejected

| Tool | Why not |
|---|---|
| [`@actions/workflow-parser`](https://www.npmjs.com/package/@actions/workflow-parser) | GitHub's own parser, so maximum authority — but no CLI, ESM-only, and imports JSON without attributes so it fails on modern Node. Needs an `esbuild --format=cjs` bundle to run at all. `actionlint`'s `syntax-check` covers the same ground with zero setup. |
| [`poutine`](https://github.com/boostsecurityio/poutine) | Subsumed by zizmor for single-repo work. Real value only at org-wide scale. |
| [`octoscan`](https://github.com/synacktiv/octoscan) | Alive and offensive-leaning; fine as a second opinion on injection, but adds little over zizmor. |
| SchemaStore + `check-jsonschema` | Zero new signal over actionlint. Also community-maintained — **no GitHub-official workflow schema exists.** |
| `act` | Local workflow execution, not analysis. Different job. |

---

## Supporting commands

```bash
gh api repos/OWNER/REPO/contents/.github/workflows --jq '.[].name'   # list without cloning
gh workflow list --json id,name,path,state
gh run list --limit 20 --json databaseId,name,conclusion,createdAt,event
gh api repos/OWNER/REPO/actions/runs/RUN_ID/jobs \
  --jq '.jobs[] | {job:.name, steps:[.steps[]|{name,started_at,completed_at}]}'
gh cache list --sort size_in_bytes --order desc --json key,sizeInBytes,lastAccessedAt
gh api repos/OWNER/REPO/commits/v5 --jq .sha                        # resolve a tag to a SHA
```

**Do not use** `/actions/runs/{id}/timing` — deprecated, returns an empty `billable` object.
