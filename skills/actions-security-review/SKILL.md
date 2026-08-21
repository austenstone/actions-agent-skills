---
name: actions-security-review
description: "Audits GitHub Actions workflows for security defects using zizmor and actionlint, ranks findings by real exploitability rather than raw rule severity, and emits exact fix diffs with live documentation citations. Use when: actions security review, is this workflow safe, review my CI for security, pin my actions, lock down GITHUB_TOKEN, harden my workflow, why is pull_request_target dangerous, pwn request triage, zizmor findings, actionlint expression correctness, OIDC trust policy review, self-hosted runner risk, 'secrets inherit' blast-radius review, artifact credential leakage, GITHUB_ENV injection, GITHUB_OUTPUT injection, or org-level Actions controls. Load alongside actions-workflow-toolkit, which provides the verified tool invocations, JSON output contract, safety contract, and canonical GitHub Actions docs map."
---

# Actions Security Review

Load [`actions-workflow-toolkit`](../actions-workflow-toolkit/SKILL.md) first. Use its verified tool invocations in [`tools.md`](../actions-workflow-toolkit/references/tools.md) and cite GitHub docs through [`docs-map.md`](../actions-workflow-toolkit/references/docs-map.md). Do not restate install commands, JSON shapes, limits, prices, or docs URL tables here.

## Execution workflow

1. **Run zizmor locally.** Use the toolkit's local `zizmor --format json` path. Security findings come from `ident`, severity, confidence, locations, fixes, and `url`. Accept `Informational` as a real severity value.
2. **Recover from hard-failed online audits.** If zizmor prints `fatal: no audit was performed`, emits empty stdout, or fails before valid JSON, do not report clean. Rerun the same pass with `--no-online-audits`; if that still cannot produce valid JSON, rerun local inputs with `--offline`. For a remote slug, `--offline` cannot collect the repository, so report the remote-context pass unavailable unless a local checkout is supplied. Label successful fallback reports as skipping network-dependent audits: `impostor-commit`, `ref-confusion`, `known-vulnerable-actions`, and `stale-action-refs`.
3. **Run zizmor remote-slug mode as a separate repo-context pass.** Use the toolkit's `OWNER/REPO` mode when a GitHub slug is available. Remote mode may collect additional auditable inputs across the repository, such as nested workflows and composite actions. Do not diff local `.github/workflows/` counts against remote counts as if they scanned the same file set.
4. **Run actionlint.** Treat it as the expression, schema, and shell correctness oracle; security fixes that break actionlint are regressions.
5. **Rank by exploitability and business priority.** Scanner severity/confidence is scanner confidence, not business priority. Present findings in this order:
   1. Exploitable privileged-trigger or data-flow paths.
   2. Injection where attacker-controlled input reaches `run`, environment files, or action inputs.
   3. Known-vulnerable or untrusted third-party supply-chain items.
   4. Permission reductions that materially reduce blast radius.
   5. Hygiene and supply-chain hardening, grouped and de-duplicated.
6. **Manually review what tools cannot prove:** org-level allowed-actions policy, rulesets on `.github/workflows/**`, CODEOWNERS ownership, artifact attestations, explicit `permissions: write-all`, cloud OIDC trust policy design, and the self-hosted runner operating model.
7. **Report in two layers.** Layer 1 is screen-share-safe consequence language. Layer 2 is file:line, rule ID, exact diff, and citation URL.

## Triage table

Cite each zizmor finding's own `url`. Do not paraphrase the rule documentation; translate it into consequence terms for this workflow.

| zizmor `ident` | Consequence to explain | Safe to auto-apply? |
|---|---|---|
| `template-injection` | Attacker-controlled event text is pasted into a generated shell script before the shell starts, so quoting inside that expression is too late. | No. Rewrite to intermediate `env:` and quote shell variables. |
| `dangerous-triggers` | `pull_request_target` or `workflow_run` can combine untrusted code/artifacts with base-repo token/secrets. | No. Requires trigger and data-flow redesign. |
| `unpinned-uses` | A mutable tag or branch can run different code tomorrow than it ran today. | Only if the fix disposition says safe; otherwise propose SHA pin diff. Never invent a SHA. |
| `known-vulnerable-actions` | The workflow calls an action version with a public advisory. Example: [`tj-actions/changed-files` CVE-2025-30066](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3). | Usually no. Upgrades can change behavior; use the fix title when present. |
| `excessive-permissions` | Jobs receive token scopes they do not need, so a separate compromise becomes a broader repo write. | Usually no. Default-deny workflow permissions, then grant per job. |
| `artipacked` | Checkout credentials can persist on disk and be swept into uploaded artifacts. | No when disposition is unsafe; `persist-credentials: false` can break later push steps. |
| `secrets-inherit` | A reusable workflow gets the caller's whole secret set instead of named secrets. | No. Replace with explicit secret mapping. |
| `self-hosted-runner` | Fork PR code can execute on infrastructure you own; persistent runners can remain compromised across jobs. | No. Requires runner policy, isolation, and trigger changes. |
| `github-env` | Untrusted writes to `GITHUB_ENV` or `GITHUB_PATH` can alter later step execution context. | No. Redesign data passing and sanitize names/values. |
| `github-app` | A GitHub App installation token can outlive the job or be issued with broader repository or permission access than the job needs. | No. Scope repository access and permissions to the operation, and do not disable token revocation without a specific reason. |
| `misfeature` | The workflow uses an Actions feature zizmor treats as hard to audit or easy to misuse. | Usually no. Replace the feature with the pattern recommended by the finding URL. |

## Review focus

### Template injection

Use [`fix-patterns.md`](references/fix-patterns.md#template-injection) for before/after YAML. Treat these event fields as untrusted input when they originate from users or commits: issue title/body, PR title/body/branch name, commit message, review body, and `head_ref`. Use the GitHub contexts/events docs from [`docs-map.md`](../actions-workflow-toolkit/references/docs-map.md) for field provenance.

### Privileged triggers

Use [`privileged-triggers.md`](references/privileged-triggers.md). `pull_request_target` and `workflow_run` run in the base repository security context; cite GitHub's [`pull_request_target` security page](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target). Current checkout behavior matters: `actions/checkout` v7+ defaults to the base branch on `pull_request_target`; grep for `allow-unsafe-pr-checkout`, not just the trigger.

### Supply chain

For `unpinned-uses`, pin to the SHA supplied in zizmor `fixes[].title`; never resolve from memory. For `known-vulnerable-actions`, cite the finding URL and any GitHub advisory URL surfaced in the location. Prefer removing abandoned third-party actions over pinning known-bad code forever.

### Permissions and credentials

Default to `permissions: {}` at workflow level, then grant per-job minimum. Cite the GITHUB_TOKEN docs through [`docs-map.md`](../actions-workflow-toolkit/references/docs-map.md). For checkout credential persistence, use [`fix-patterns.md`](references/fix-patterns.md#checkout-credentials-and-artifacts) and call out unsafe fixes.

### Manual-only controls

Use [`org-controls.md`](references/org-controls.md). A workflow fix is incomplete if the org still allows recurrence through unrestricted third-party actions, unprotected workflow file edits, missing CODEOWNERS, weak OIDC trust policies, or public-repo self-hosted runners.

## Output contract

Use [`report-template.md`](references/report-template.md). Two layers are mandatory:

- **Layer 1:** exploitability-ranked consequence summary, no rule IDs, no internal scanner noise, safe to screen-share.
- **Layer 2:** `file:line`, rule ID, exact diff, citation URL, and whether the change is behavior-preserving.

### Scale mode

Trigger scale mode when the repo has more than 25 workflows or more than 100 total findings.

Scale mode is mandatory:

- Group by workflow family, rule, action owner, and trigger trust boundary.
- Collapse repeated `unpinned-uses` by action owner. Split GitHub-owned `actions/*` from third-party owners.
- Publish a top-10 "fix first" list. Do not paste hundreds of findings into the main report.
- Put raw scanner rows in an appendix.
- Call out when duplicated findings across many reusable workflows point to platform or governance work, not independent one-off fixes.

## False-positive discipline

A clean workflow gets a clean report. Do **not** flag:

- `pull_request_target` by itself when it never checks out PR head, never runs PR code, and only writes labels/comments with tight permissions.
- `workflow_run` by itself when it ignores untrusted artifacts and never checks out or executes upstream code.
- First-party `actions/*` tag pins as the same risk as unknown third-party action tag pins. Still prefer SHA pins, but keep first-party pinning in the grouped hardening layer unless it combines with an exploit path.
- Low-confidence cache-poisoning as urgent without a release or privileged publish path that makes cache contents security-relevant.
- `artipacked` hygiene in the top layer unless checkout credentials can realistically reach artifacts or attacker-controlled paths.
- `permissions: contents: read` as excessive when checkout is the only repo operation.
- `persist-credentials: true` when a later audited step intentionally pushes and artifacts cannot include the credential path.
- `secrets: inherit` without first explaining whether the callee needs every caller secret and who can change that callee.

If the tool is clean and the manual checks are clean, say that. Noise trains people to ignore the review.
