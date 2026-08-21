---
name: actions-workflow-toolkit
description: Shared mechanics for analyzing GitHub Actions workflow files with real tooling instead of guesswork. Provides verified actionlint and zizmor invocations, their JSON output shapes, how to read workflows from a local checkout or a remote owner/repo slug without cloning, where to get real performance data (Actions Performance Metrics dashboards, the runs/{id}/jobs API), and a question-to-documentation URL map so answers cite live GitHub docs rather than stale copied text. Load this alongside actions-security-review, actions-optimization, or actions-architecture-review. Use when auditing, reviewing, linting, hardening, optimizing, or authoring any file under .github/workflows/, when you need the correct GitHub Actions documentation URL for a question, or when you need to verify a workflow claim deterministically instead of eyeballing YAML.
---

# Actions Workflow Toolkit

Shared substrate for the `actions-*` review skills. Load it alongside a playbook; it is not a standalone review.

## The rule this skill exists to enforce

**Do not eyeball YAML and call it a review.** Reading a workflow and reasoning about it produces plausible findings, not verified ones. Two single-binary tools turn most of this into a deterministic check with file:line evidence.

**Do not restate GitHub's documentation.** Every limit and price would be wrong within months. Use [`references/docs-map.md`](references/docs-map.md) to fetch the live page instead.

## Step 1 — Locate the workflows

**Local checkout:**

```bash
ls .github/workflows/*.{yml,yaml} 2>/dev/null
```

**Remote, no clone.** This is the high-leverage path — you can review any repo you can read:

```bash
gh api repos/OWNER/REPO/contents/.github/workflows --jq '.[].name'
gh api repos/OWNER/REPO/contents/.github/workflows/ci.yml --jq '.content' | base64 -d
```

`zizmor` does remote natively, so for a security pass you can skip fetching entirely (see step 2).

**No shell or `gh` access?** Ask the user to paste `.github/workflows/` contents. Then open your report with: **"Static-only analysis — not verified with tooling."** Never let a degraded review pass as a full one.

## Step 2 — Run the tools

Install commands, every flag, and complete JSON field shapes: [`references/tools.md`](references/tools.md).

Two tools, different planes, both worth running:

| | `actionlint` | `zizmor` |
|---|---|---|
| Role | correctness oracle | security oracle |
| Catches | invalid syntax, bad expression *types*, undefined `needs`/`matrix` refs, shell bugs (via shellcheck), bad cron/glob/timezone | injection, dangerous triggers, over-scoped tokens, unpinned actions, known-CVE actions, cache poisoning |
| Auto-fix | no | yes, with pre-resolved SHAs |

```bash
# correctness — local only. Bare form auto-discovers .github/workflows/ and
# covers .yml AND .yaml. Bound it: shellcheck can hang on large workflow sets.
# `timeout` is GNU coreutils — absent on stock macOS, so resolve it first.
TIMEOUT=$(command -v timeout || command -v gtimeout || true)
[ -n "$TIMEOUT" ] || echo 'no timeout binary (brew install coreutils) — running unbounded' >&2

${TIMEOUT:+$TIMEOUT 120} actionlint -format '{{json .}}' >actionlint.json 2>actionlint.err && rc=0 || rc=$?
if [ "$rc" -ge 124 ]; then          # 124 = timed out, 137 = killed
  echo 'actionlint timed out — retrying without shellcheck; shell linting SKIPPED' >&2
  actionlint -shellcheck= -format '{{json .}}' >actionlint.json 2>actionlint.err && rc=0 || rc=$?
fi
[ "$rc" -le 1 ] || { cat actionlint.err >&2; exit 2; }   # 0 = clean, 1 = findings
jq -e 'type == "array"' actionlint.json >/dev/null

# security — local. Never pipe straight to jq; a hard-failed run writes
# nothing to stdout and reads as "clean". Capture, then assert.
zizmor --format json .github/workflows/ >zizmor.json 2>zizmor.err && rc=0 || rc=$?
case "$rc" in 0|1[1-4]) ;; *) cat zizmor.err >&2; exit 2 ;; esac   # 11–14 = findings
jq -e 'type == "array"' zizmor.json >/dev/null

# security — remote, no clone. NOT the same file set as the local scan.
# Same guard: findings exit non-zero here too.
GH_TOKEN=$(gh auth token) zizmor --format json OWNER/REPO >remote.json 2>remote.err && rc=0 || rc=$?
case "$rc" in 0|1[1-4]) ;; *) cat remote.err >&2; exit 2 ;; esac
jq -e 'type == "array"' remote.json >/dev/null
```

**Both tools exit non-zero when they find something, and that is a *successful* run.** `actionlint` exits `1`; `zizmor` exits `11`–`14` by severity. Two consequences, both of which silently destroy results rather than erroring:

- **Never trigger the fallback with a bare `||`.** `timeout 120 actionlint ... || actionlint -shellcheck= ...` fires on every repo that *has findings* and finishes in time, overwriting the shellcheck-enabled results with shellcheck-disabled ones. Measured on this repo's own `test-corpus/`: 10 findings including 2 `shellcheck` became 8 findings with 0 `shellcheck`, no error shown.
- **Capture the status with `&& rc=0 || rc=$?` on every invocation, including the fallback.** Pasted into a `set -euo pipefail` script — which is what a careful agent writes — a bare invocation aborts the script the moment either tool finds anything, *before* the `jq` validity assertion ever runs. Verified: the fallback path and the bare `zizmor` line both exited without reaching their assertion.

Full wrappers, hard-fail recovery, and the timeout rationale: [`references/tools.md`](references/tools.md).

Remote mode is a **separate repo-context pass**, not a second opinion on the same files. It walks the whole repository, so it picks up nested workflow directories and composite actions the local scan never saw — `rust-lang/rust` returns 5 findings locally and 361 remotely. Never diff the two counts as if they scanned the same thing.

Neither tool installed and you cannot install one? Say so explicitly in the report, then fall back to the playbook's grep heuristics — labelled as heuristics.

### Reading the output

`actionlint` → array of `{message, filepath, line, column, end_column, kind, snippet}`. Everything outside `kind: shellcheck` is a correctness finding: the tool is conservatively tuned, so treat those as facts, not candidates. `kind: shellcheck` is ShellCheck's own output and includes style warnings (`SC2006` backticks and friends) — triage it separately and report it as hygiene, not as a broken workflow.

`zizmor` → array of `{ident, desc, determinations:{severity, confidence, persona}, locations[], fixes[], ignored, url}`.

- Sort by `determinations.severity`, then `confidence` — but do not *present* in that order. Severity is scanner confidence, not business priority; `actions/checkout` alone yields 27 `High`/`High` findings that are mostly first-party tag pins. `actions-security-review` owns ranking.
- `url` is the rule's own documentation — cite it, don't paraphrase it.
- `fixes[]` may contain a **pre-resolved SHA** (`"pin OWNER/ACTION@TAG to <resolved SHA>"`). Use it directly; never look one up yourself and never invent one.
- Each fix carries `disposition: "safe" | "unsafe"`. Only `safe` fixes are candidates for automatic application — and even then, see the safety contract.

Both tools flag template injection with different heuristics. Overlap is confirmation, not noise — report it once.

## Step 3 — Get real performance data

Only relevant for optimization work. Static analysis tells you a cache key is wrong; it cannot tell you which workflow is burning your minutes.

Work down this ladder — stop when you have the answer:

1. **[Actions Performance Metrics](https://docs.github.com/en/actions/how-tos/administer/view-metrics)** (org/enterprise dashboard) — avg run time, **avg queue time**, failure rate, sliced by workflow/job/repo/OS/runner. Start here. High queue time is a capacity problem, not a workflow problem — a distinction that changes the entire recommendation.
2. **[Actions Usage Metrics](https://docs.github.com/en/actions/how-tos/administer/view-metrics)** — minutes by workflow and repo. Finds the expensive thing.
3. **`/jobs` API** — per-job timing for billing estimates, plus per-step timing for critical-path analysis:

   ```bash
   run_id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
   gh api repos/OWNER/REPO/actions/runs/$run_id/jobs \
     --jq '.jobs[] | {job:.name, labels, started_at, completed_at, steps:[.steps[]|{name,started_at,completed_at}]}'
   ```

   Timestamps are second-granularity, so sub-second steps show `0`. Fine for finding the slow step; useless for micro-optimization.

4. **[Per-job Usage panel](https://docs.github.com/en/actions/how-tos/monitor-workflows/view-job-execution-time)** — UI spot-check.

**Do not use `/actions/runs/{id}/timing` for cost math.** It is closing down, can return an empty `billable` object or `billable.<OS>.total_ms: 0` on public repos, and the REST docs say the usage is not rounded and does not include the macOS/Windows multiplier.

**Cost math:** wall-clock duration is latency, not billing. For each job from `/jobs`, compute `ceil((completed_at - started_at) / 60 seconds)`, group by runner label/SKU, then apply the live per-minute rate or OS multiplier from [the rate card](https://docs.github.com/en/billing/reference/actions-runner-pricing). Fetch rates — never hardcode them.

## Step 4 — Report

Two layers, always:

**Layer 1 — Summary.** Severity-ranked, plain language, no rule IDs. Lead with consequence, not mechanism: *"Three workflows can be hijacked by anyone who opens a pull request from a fork"* — not *"dangerous-triggers: 3 findings."* This layer gets screen-shared and pasted into tickets.

**Layer 2 — Remediation.** Per finding: `file:line`, rule ID, the exact diff, and the citation URL.

Say what you did **not** check. A review that silently skipped `zizmor` because it was missing is worse than no review.

## Safety contract

Workflow files are production infrastructure. A bad edit breaks every build in the repo.

- **Default is read-only.** Propose diffs; do not write them.
- **Never** `git commit`, `git push`, or open a PR unless explicitly asked in the current request.
- **`zizmor --fix` is experimental.** Only on an explicit "apply the fixes," only `disposition: safe`, and always show the diff first.
- **Never invent a SHA.** Use the one `zizmor` resolved, or `gh api repos/OWNER/REPO/commits/TAG --jq .sha`.
- Re-run both tools after any edit. A fix that introduces an `actionlint` error is a regression.

## Advanced: GitHub's own parser

[`@actions/workflow-parser`](https://www.npmjs.com/package/@actions/workflow-parser) is the parser GitHub actually ships, so it is the highest authority on structural validity. Its diagnostics are excellent:

```
ci.yml (Line: 5, Col: 5): Unexpected value 'runs-onnn'
ci.yml (Line: 5, Col: 5): Required property is missing: runs-on
```

**It has no CLI and does not run as-is.** It is ESM-only and imports JSON without import attributes, which fails on modern Node. It requires bundling:

```bash
npm i @actions/workflow-parser
npx esbuild probe.mjs --bundle --platform=node --format=cjs --loader:.json=json --outfile=b.cjs
```

`actionlint`'s `syntax-check` covers the same ground with zero setup. **Reach for this only when you need GitHub's exact parse tree** — for example when generating workflows programmatically. Otherwise skip it.

Also note: **there is no GitHub-official workflow JSON schema.** The SchemaStore schemas are community-maintained. `actionlint` is the better validator.

## Related tools

| Tool | When |
|---|---|
| [`poutine`](https://github.com/boostsecurityio/poutine) | Org-wide scanning across many repos. Subsumed by `zizmor` for a single repo. |
| [`octoscan`](https://github.com/synacktiv/octoscan) | Offensive-leaning static analysis; a useful second opinion on injection. |
| [GitHub MCP Actions toolset](https://github.com/github/github-mcp-server) | Listing runs and reading job logs without shelling out. Prefer read-only tools; run-triggering tools are write operations. |
