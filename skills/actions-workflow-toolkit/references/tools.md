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

Prefer the bare form. It auto-discovers `.github/workflows/` and picks up **both** `.yml` and `.yaml`; an explicit `*.yml` glob silently skips `.yaml` workflows.

```bash
actionlint -format '{{json .}}'                           # all findings as one JSON array
actionlint -shellcheck= -format '{{json .}}'              # same, minus shell linting
actionlint -ignore 'regex matching messages to drop'
actionlint -init-config                                   # write a starter actionlint.yaml
```

Exit codes: `0` clean · `1` findings · `2` invalid option · `3` fatal.

**Always run it under a timeout, and fall back on hang.** actionlint shells out to `shellcheck` once per `run:` block. On large workflow sets this can stall for minutes with no output — measured to exceed 120s on 7 of 10 real public repos (`cli/cli`, `vercel/next.js`, `home-assistant/core`, `rust-lang/rust`, `denoland/deno`, `pytorch/pytorch`, `pandas-dev/pandas`). A hang is indistinguishable from work in progress, so an agent that does not bound it either blocks forever or quietly skips correctness review.

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || true)
[ -n "$TIMEOUT" ] || echo 'no timeout binary (brew install coreutils) — running unbounded' >&2

${TIMEOUT:+$TIMEOUT 120} actionlint -format '{{json .}}' > actionlint.json || {
  echo 'actionlint timed out or failed; retrying without shellcheck' >&2
  actionlint -shellcheck= -format '{{json .}}' > actionlint.json
}
```

`timeout` ships with GNU coreutils and is **absent from stock macOS**. Resolve it into a variable first, as above. A bare `timeout 120 actionlint ... || actionlint -shellcheck= ...` is a trap: without coreutils the shell returns `127` instantly, the fallback fires on *every* run, and shell linting is silently skipped forever while the command still appears to succeed.

If you fall back, **say so in the report**: shell linting inside `run:` blocks was skipped. The fallback returns instantly on every repo measured, and still catches all YAML, expression, and workflow-syntax errors.

### Output shape

```json
[{
  "message": "invalid CRON format \"0 25 * * *\" in schedule event: end of range (25) above maximum (23): 25",
  "filepath": "test-corpus/broken.yml",
  "line": 10,
  "column": 13,
  "kind": "events",
  "snippet": "    - cron: '0 25 * * *' # invalid hour\n            ^~",
  "end_column": 14
}]
```

Useful `kind` values: `syntax-check`, `expression`, `shellcheck`, `matrix`, `events`, `job-needs`, `action`, `workflow-call`, `glob`, `runner-label`, `credentials`.

**Split `shellcheck` findings from the rest.** Everything actionlint reports outside `kind: shellcheck` is a correctness finding: it is conservatively tuned, and if it says an expression is wrong, it is wrong. `kind: shellcheck` is a different class — it carries ShellCheck's own style warnings. Measured: 5 of `sveltejs/svelte`'s 7 findings were `SC2006` backtick-style warnings, which do not belong next to an undefined-expression bug in a report. Triage those by ShellCheck severity and treat most as hygiene.

### What it uniquely catches

Expression **type** checking · undefined `needs`/`steps`/`matrix` references · cyclic job dependencies · shellcheck + pyflakes inside `run:` · cron syntax and frequency · glob patterns · IANA timezones · webhook event and payload validation · local action inputs plus embedded popular-action input checks · reusable workflow I/O contracts.

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
```

There is no `--only` flag in v1.29.0. Use severity/confidence filters, inline ignores, or config ignores for noise control.

Exit codes: `0` clean · `1` audit error · `2` argument error · `3` no inputs · `11` informational findings · `12` low · `13` medium · `14` high. `--no-exit-codes` and `--format sarif` suppress finding exit codes.

### Output shape

```json
[{
  "ident": "unpinned-uses",
  "desc": "unpinned action reference",
  "determinations": { "severity": "High", "confidence": "High", "persona": "Regular" },
  "url": "https://docs.zizmor.sh/audits/#unpinned-uses",
  "locations": [{
    "symbolic": {
      "key": { "Local": { "verbatim_path": "test-corpus/insecure.yml" } },
      "annotation": "action is not pinned to a hash (required by blanket policy)",
      "route": { "route": [{ "Key": "jobs" }, { "Key": "pwn-request" }, { "Key": "steps" }, { "Index": 0 }, { "Key": "uses" }] },
      "feature_kind": { "Subfeature": { "after": 0, "fragment": { "Raw": "actions/checkout@v7" } } },
      "kind": "Primary"
    },
    "concrete": {
      "location": {
        "start_point": { "row": 18, "column": 14 },
        "end_point": { "row": 18, "column": 33 },
        "offset_span": { "start": 599, "end": 618 }
      },
      "feature": "actions/checkout@v7",
      "comments": []
    }
  }],
  "ignored": false,
  "fixes": [{
    "title": "pin actions/checkout@v7 to 11d5960a326750d5838078e36cf38b85af677262",
    "key": { "Local": { "verbatim_path": "test-corpus/insecure.yml" } },
    "disposition": "unsafe"
  }]
}]
```

**`concrete.location.start_point.row` is 0-indexed.** Add 1 for a human line number.

### The one jq recipe worth memorizing

**Never pipe `zizmor` straight into `jq`, and never send its stderr to `/dev/null`.** When an online audit cannot resolve a referenced repo, zizmor aborts the *entire* run: it prints `fatal: no audit was performed` to stderr and writes **nothing** to stdout. `jq` on empty input exits `0` and prints nothing, so a crashed scan is indistinguishable from a clean one. An agent following the naive pipe will hand the customer a false clean bill of health. Measured on `vercel/next.js` (local and remote) and `pandas-dev/pandas` (remote).

Capture both streams, then assert you actually got JSON:

```bash
if ! zizmor --format json .github/workflows/ >zizmor.json 2>zizmor.err; then
  if grep -qE 'fatal: no audit was performed|no inputs collected|couldn.t list (tags|branches)' zizmor.err; then
    cat zizmor.err >&2
    echo 'zizmor hard-failed. Retry with --no-online-audits, then --offline.' >&2
    exit 2
  fi
fi

jq -e 'type == "array"' zizmor.json >/dev/null   # fail loudly on empty or non-JSON

jq -r '.[] | "\(.determinations.severity)\t\(.determinations.confidence)\t\(.ident)\t\(.locations[0].concrete.location.start_point.row + 1)"' zizmor.json
```

A findings-producing run exits non-zero by design (`11`–`14` by severity), which is why the `if !` guard inspects stderr instead of trusting the exit code alone. Do not infer clean-vs-failed from the exit code: require valid JSON.

On hard failure, retry `--no-online-audits`, then `--offline`. Both recovered the `vercel/next.js` scan immediately. Report that network-dependent audits (`impostor-commit`, `ref-confusion`, `known-vulnerable-actions`, `stale-action-refs`) were skipped.

```
High	High	template-injection	11
High	High	known-vulnerable-actions	13
High	High	unpinned-uses	10
High	Medium	dangerous-triggers	2
Medium	Medium	excessive-permissions	7
Medium	Low	artipacked	10
```

Severity ∈ `Informational|Low|Medium|High`. Confidence ∈ `Low|Medium|High`.

**Sort by severity and confidence, but do not present in that order.** Severity is the scanner's confidence that a pattern matched, not the customer's business priority. `actions/checkout` — a well-maintained first-party repo — yields 27 `High`/`High` findings, nearly all first-party tag pins and `:latest` test containers. Leading with those buries the one finding that matters. `actions-security-review` owns the ranking and false-positive discipline; apply it before showing a human anything.

### Fixes

`fixes[].title` often contains a **pre-resolved commit SHA** — `"pin OWNER/ACTION@TAG to <resolved SHA>"`. Use that string; never resolve or invent a SHA yourself.

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
| Permissions & secrets | `excessive-permissions`, `undocumented-permissions`, `secrets-inherit`, `overprovisioned-secrets`, `secrets-outside-env`, `unredacted-secrets`, `github-app` |
| Supply chain | `unpinned-uses`, `unpinned-images`, `unpinned-tools`, `known-vulnerable-actions`, `impostor-commit`, `typosquat-uses`, `forbidden-uses`, `stale-action-refs`, `archived-uses`, `ref-confusion`, `ref-version-mismatch`, `adhoc-packages` |
| Credentials | `artipacked`, `hardcoded-container-credentials`, `use-trusted-publishing` |
| Cache & capacity | `cache-poisoning`, `concurrency-limits` |
| Hygiene & config | `self-hosted-runner`, `self-repository`, `obfuscation`, `misfeature`, `anonymous-definition`, `insecure-url-scheme`, `superfluous-actions`, `dependabot-cooldown`, `dependabot-execution` |

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
| Single binary + JSON output | ✅ | ✅ |
| SARIF output | ❌ | ✅ |
| Offline/no-online mode flag | ❌ | ✅ |

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
  --jq '.jobs[] | {job:.name, labels, started_at, completed_at, steps:[.steps[]|{name,started_at,completed_at}]}'
gh cache list --sort size_in_bytes --order desc --json key,sizeInBytes,lastAccessedAt
gh api repos/OWNER/REPO/commits/v5 --jq .sha                        # resolve a tag to a SHA
```

**Do not use** `/actions/runs/{id}/timing` for cost math. It is closing down, can return an empty `billable` object or `billable.<OS>.total_ms: 0` on public repos, and the REST docs say the usage is not rounded and does not include the macOS/Windows multiplier.

For cost estimates, use `/jobs`: round each job duration up to the nearest minute, sum by runner label/SKU, then apply the live per-minute rate or OS multiplier from [the rate card](https://docs.github.com/en/billing/reference/actions-runner-pricing). Workflow wall-clock duration is latency, not billing.
