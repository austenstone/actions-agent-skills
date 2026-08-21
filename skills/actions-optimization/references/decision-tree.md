# Actions Optimization Decision Tree

Use this after the toolkit has supplied Performance Metrics, Usage Metrics, and `/jobs` step timings. The point is to choose the lever, not admire YAML.

## 1. Queue time branch

**Conclusion:** high queue time is capacity or concurrency pressure. It is not evidence that the workflow body is slow. The dashboard source is listed in [`docs-map.md#measurement-and-troubleshooting`](../../actions-workflow-toolkit/references/docs-map.md#measurement-and-troubleshooting).

Ask:

- Is queue time high across many workflows on the same runner label? That points to runner supply or org concurrency.
- Is queue time high only for one matrix-heavy workflow? That points to `max-parallel`, matrix fan-out, or runner label scarcity.
- Are newer commits waiting behind older PR runs? That points to missing `concurrency.cancel-in-progress`.

Recommended levers:

| Evidence | Repo YAML lever | Org-level lever |
|---|---|---|
| Superseded PR runs queued or running | Add safe workflow-level `concurrency` | None |
| Matrix floods runners | Add `max-parallel` only when it reduces queue without hiding useful parallelism | Add capacity or change runner class |
| All jobs on one self-hosted label wait | None, unless label choice is wrong | Add runners, fix runner scale set, or route to hosted runners |
| Hosted larger runner jobs wait | None first | Check runner group availability and quota |

Do not recommend cache, Docker tuning, or checkout tuning until queue time is no longer the dominant latency.

## 2. Failure-rate branch

**Conclusion:** reruns convert one workflow into multiple paid executions. The dashboard exposes failure rate by workflow/job/repo/OS/runner via the metrics docs linked in [`docs-map.md#measurement-and-troubleshooting`](../../actions-workflow-toolkit/references/docs-map.md#measurement-and-troubleshooting).

Ask:

- Is the same job failing intermittently and passing on rerun?
- Are dependency downloads, service containers, or external APIs the failing step?
- Does `strategy.fail-fast` stop useless matrix legs, or does it hide needed diagnostics?
- Are canceled superseded PR runs counted separately from failures in the dashboard?

Recommended levers:

| Evidence | Lever |
|---|---|
| Flaky test job dominates failures | Stabilize test isolation, seed data, timeouts, service readiness, or quarantine policy before runtime tuning |
| External dependency fetch fails | Cache package-manager store, pin mirrors, or retry the fetch step deliberately |
| Matrix continues after a decisive failure | Use `strategy.fail-fast` when later legs do not add diagnostic value |
| PR authors push many revisions | Add `concurrency.cancel-in-progress` scoped to PR events |

Savings estimate is reruns avoided × full failed-run wall-clock × live rate card. Do not use public-repo `billable.total_ms`; toolkit explains why.

## 3. Trigger waste branch

**Conclusion:** the workflow runs correctly but too often.

Ask:

- Does Usage Metrics show one workflow consuming minutes on docs-only or unrelated monorepo changes?
- Is the workflow required by branch protection?
- Does the repo use merge queue, reusable workflows, or generated changes that path filters might miss?

Recommended levers:

| Evidence | Lever | Guardrail |
|---|---|---|
| Docs-only changes run full CI | Add `paths`/`paths-ignore` or a change-detection job | Required checks need a success-reporting companion workflow if filtered out |
| Monorepo package builds all packages | Generate a dynamic matrix with changed packages | Keep global integration tests if they protect shared contracts |
| Heavy workflow runs on every push and PR | Narrow triggers or add concurrency | Do not skip default branch validation |

Trigger and path syntax live in [`docs-map.md#syntax-and-semantics`](../../actions-workflow-toolkit/references/docs-map.md#syntax-and-semantics).

## 4. Runtime branch

Use `/jobs` step timings from the toolkit to find the critical path. Then map the slow step to one lever.

| Slow area | First lever | Second lever |
|---|---|---|
| Dependency install | `setup-*` cache input or package-manager store cache | Lockfile hygiene and branch-scope expectations |
| Test execution | Runner architecture or sizing experiment | Matrix split only when branches are long and independent |
| Docker build | `buildx` cache with `type=gha` scope | Registry cache and layer ordering |
| Checkout | Sparse checkout | Remove unnecessary LFS/submodule fetches |
| Many tiny jobs | Consolidate jobs | Keep split only when parallelism beats fixed overhead |
| One huge serialized job | Split independent long phases | Larger runner if parallelism exists inside the tool |

## 5. Runner-sizing arithmetic

Runner sizing is a measurement experiment, not a vibe.

```text
current_cost = current_minutes × current_rate
candidate_cost = candidate_minutes × candidate_rate
savings = current_cost - candidate_cost
```

Use the live pricing page referenced in [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost). Larger runners have distinct billing behavior from included minutes; cite the live docs instead of copying the rule here.

Decision rule:

- If wall-clock improves less than the rate multiplier, cost rises.
- If wall-clock improves more than the rate multiplier, cost falls.
- If latency matters more than cost, say that explicitly and do not sell it as savings.
