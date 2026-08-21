# GitHub Actions Documentation Map

**Question → canonical URL.** Fetch the page. Do not answer from memory, and do not copy these pages into this repo — limits, prices, and runner specs change, and a stale local copy is worse than no copy.

All URLs verified live. If one 404s, start from [`/en/actions/reference`](https://docs.github.com/en/actions/reference) rather than guessing a path.

## Syntax and semantics

| Question | URL |
|---|---|
| Full `jobs.*.steps.*` field list, `permissions:`, `concurrency:` syntax | [`/reference/workflows-and-actions/workflow-syntax`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) |
| What does `on.<event>` do, what fields does it carry | [`/reference/workflows-and-actions/events-that-trigger-workflows`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) |
| Is this `${{ }}` valid, what functions exist | [`/reference/workflows-and-actions/expressions`](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions) |
| What properties exist on `github.`, `needs.`, `matrix.` | [`/reference/workflows-and-actions/contexts`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) |
| `action.yml` schema, composite action `runs:` | [`/reference/workflows-and-actions/metadata-syntax`](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax) |
| `workflow_call` inputs/outputs/secrets, nesting rules | [`/how-tos/reuse-automations/reuse-workflows`](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) |
| Variables, `GITHUB_ENV`, `GITHUB_OUTPUT` | [`/reference/workflows-and-actions/variables`](https://docs.github.com/en/actions/reference/workflows-and-actions/variables) |

## Security

| Question | URL |
|---|---|
| **Start here for any hardening question** | [`/reference/security/secure-use`](https://docs.github.com/en/actions/reference/security/secure-use) |
| Why is `pull_request_target` dangerous, how to use it safely | [`/reference/security/securely-using-pull_request_target`](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target) |
| OIDC token claims, `sub` format, trust policy design | [`/reference/security/oidc`](https://docs.github.com/en/actions/reference/security/oidc) |
| OIDC setup for a specific cloud | `/how-tos/secure-your-work/security-harden-deployments/oidc-in-{aws,azure,google-cloud-platform}` |
| Secret naming rules, size limits, redaction behavior | [`/reference/security/secrets`](https://docs.github.com/en/actions/reference/security/secrets) |
| `GITHUB_TOKEN` default permissions and scoping | [`/tutorials/authenticate-with-github_token`](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token) |
| Artifact attestations / build provenance | [`/how-tos/secure-your-work/use-artifact-attestations`](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations) |

## Performance and cost

| Question | URL |
|---|---|
| Cache key matching, `restore-keys` algorithm, size limits | [`/reference/workflows-and-actions/dependency-caching`](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) |
| Viewing and deleting caches, `gh cache` CLI | [`/how-tos/manage-workflow-runs/manage-caches`](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manage-caches) |
| Language-specific cache paths, advanced strategies | [`actions/cache` README](https://raw.githubusercontent.com/actions/cache/main/README.md) *(action's own repo, not docs)* |
| `concurrency.group`, `cancel-in-progress`, `queue` | [`/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency`](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) |
| Matrix `include`/`exclude`/`fail-fast`/`max-parallel` | [`/how-tos/write-workflows/choose-what-workflows-do/run-job-variations`](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations) |
| **Runner specs and `runs-on` labels** (incl. ARM64) | [`/reference/runners/github-hosted-runners`](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) |
| Larger runner sizes, GPU options, limitations | [`/reference/runners/larger-runners`](https://docs.github.com/en/actions/reference/runners/larger-runners) |
| Self-hosted runners, label routing precedence, ARC | [`/reference/runners/self-hosted-runners`](https://docs.github.com/en/actions/reference/runners/self-hosted-runners) |
| **Per-minute USD rate for every runner SKU** | [`/billing/reference/actions-runner-pricing`](https://docs.github.com/en/billing/reference/actions-runner-pricing) |
| Free minutes per plan, storage billing model | [`/billing/concepts/product-billing/github-actions`](https://docs.github.com/en/billing/concepts/product-billing/github-actions) |
| Who gets billed for a reusable workflow | [`/concepts/billing-and-usage`](https://docs.github.com/en/actions/concepts/billing-and-usage) |

## Limits

| Question | URL |
|---|---|
| **Every hard number** — matrix size, run time, retention, cache, secrets, artifacts, API rate | [`/reference/limits`](https://docs.github.com/en/actions/reference/limits) |

Fetch this page. Do not quote numbers from memory — they move.

Common traps. Fetch the linked page before quoting the number:

- **Reusable workflow nesting: 10 levels total** — the top-level caller plus up to 9 nested. Older documentation said 4. ([source](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows))
- **Matrix expansion ceiling** lives on the [limits page](https://docs.github.com/en/actions/reference/limits). Do not quote the old number from memory.

## Measurement and troubleshooting

| Question | URL |
|---|---|
| **Org dashboards: run time, queue time, failure rate** | [`/how-tos/administer/view-metrics`](https://docs.github.com/en/actions/how-tos/administer/view-metrics) |
| Usage vs performance metrics — what's the difference | [`/concepts/metrics`](https://docs.github.com/en/actions/concepts/metrics) |
| Per-job execution time in the UI | [`/how-tos/monitor-workflows/view-job-execution-time`](https://docs.github.com/en/actions/how-tos/monitor-workflows/view-job-execution-time) |
| Enable debug logging | [`/how-tos/monitor-workflows/enable-debug-logging`](https://docs.github.com/en/actions/how-tos/monitor-workflows/enable-debug-logging) |

## Migration

| Question | URL |
|---|---|
| Automated migration (Actions Importer) | `/tutorials/migrate-to-github-actions/automated-migrations/{jenkins,gitlab,azure-devops}-migration` |
| Manual concept mapping | `/tutorials/migrate-to-github-actions/manual-migrations/migrate-from-{jenkins,gitlab-cicd,azure-pipelines}` |

## Non-GitHub sources worth citing

| Source | Use for |
|---|---|
| [zizmor audit docs](https://docs.zizmor.sh/audits/) | Per-rule rationale. Every `zizmor` finding's `url` field points here — cite it directly. |
| [actionlint checks](https://github.com/rhysd/actionlint/blob/main/docs/checks.md) | What each `actionlint` rule verifies. |
| [SchemaStore `github-workflow.json`](https://json.schemastore.org/github-workflow.json) | Community schema. **Not GitHub-official.** Prefer `actionlint`. |

## Gotchas worth knowing before you recommend something

These are behaviors that surprise people, verified against the pages above. Confirm against live docs before asserting them to a user.

- **`ubuntu-latest` is not one machine.** Public and private repos can resolve to different specs for the same label. Check [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) before explaining a runtime delta.
- **Larger runners never consume included minutes.** They bill at the published per-minute rate even on paid plans. Check [larger runners](https://docs.github.com/en/actions/reference/runners/larger-runners) and the [rate card](https://docs.github.com/en/billing/reference/actions-runner-pricing) before doing sizing math.
- **ARM64 labels and rates move.** Check [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) for current labels and the [rate card](https://docs.github.com/en/billing/reference/actions-runner-pricing) for current pricing.
- **`actions/checkout` has an `allow-unsafe-pr-checkout` input.** Verify the `action.yml` for the tag in use; if it exists, grep for the opt-out instead of assuming the classic `pull_request_target` checkout footgun.
- **Cache is branch-scoped.** A feature branch cannot read a sibling branch's cache — only its own and the default branch's. Explains "why does my cache never hit."
- **Reusable workflows bill the caller,** not the repo hosting the workflow.
