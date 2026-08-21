---
name: actions-security-review
description: "Audits GitHub Actions workflows for security defects using zizmor and actionlint, ranks findings by real exploitability rather than raw rule severity, and emits exact fix diffs with live documentation citations. Use when: actions security review, is this workflow safe, review my CI for security, pin my actions, lock down GITHUB_TOKEN, harden my workflow, why is pull_request_target dangerous, pwn request triage, zizmor findings, actionlint expression correctness, OIDC trust policy review, self-hosted runner risk, 'secrets inherit' blast-radius review, artifact credential leakage, GITHUB_ENV injection, GITHUB_OUTPUT injection, or org-level Actions controls. Load alongside actions-workflow-toolkit, which provides the verified tool invocations, JSON output contract, safety contract, and canonical GitHub Actions docs map."
---

# Actions Security Review

Load [`actions-workflow-toolkit`](../actions-workflow-toolkit/SKILL.md) first. Use its verified tool invocations in [`tools.md`](../actions-workflow-toolkit/references/tools.md) and cite GitHub docs through [`docs-map.md`](../actions-workflow-toolkit/references/docs-map.md). Do not restate install commands, JSON shapes, limits, prices, or docs URL tables here.

## Execution workflow

1. **Run zizmor locally.** Use the toolkit's local `zizmor --format json` path. Security findings come from `ident`, severity, confidence, locations, fixes, and `url`.
2. **Run zizmor remote-slug mode.** Use the toolkit's `OWNER/REPO` mode for the same target when a GitHub slug is available. This catches repo-context-dependent audits and proves the review is not tied to a stale checkout.
3. **Run actionlint.** Treat it as the expression, schema, and shell correctness oracle; security fixes that break actionlint are regressions.
4. **Rank findings.** Sort by severity, then confidence, then exploitability from the workflow context. High/high remote-code-execution or credential-exposure findings go first.
5. **Manually review what tools cannot prove:** org-level allowed-actions policy, rulesets on `.github/workflows/**`, CODEOWNERS ownership, artifact attestations, explicit `permissions: write-all`, cloud OIDC trust policy design, and the self-hosted runner operating model.
6. **Report in two layers.** Layer 1 is screen-share-safe consequence language. Layer 2 is file:line, rule ID, exact diff, and citation URL.

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

- **Layer 1:** severity-ranked consequence summary, no rule IDs, no internal scanner noise, safe to screen-share.
- **Layer 2:** `file:line`, rule ID, exact diff, citation URL, and whether the change is behavior-preserving.

## False-positive discipline

A clean workflow gets a clean report. Do **not** flag:

- `pull_request_target` by itself when it never checks out PR head, never runs PR code, and only writes labels/comments with tight permissions.
- `workflow_run` by itself when it ignores untrusted artifacts and never checks out or executes upstream code.
- First-party `actions/*` tag pins as the same risk as unknown third-party action tag pins. Still prefer SHA pins, but rank the consequence honestly.
- `permissions: contents: read` as excessive when checkout is the only repo operation.
- `persist-credentials: true` when a later audited step intentionally pushes and artifacts cannot include the credential path.
- `secrets: inherit` without first explaining whether the callee needs every caller secret and who can change that callee.

If the tool is clean and the manual checks are clean, say that. Noise trains people to ignore the review.
