# Savings Math and Report Shape

Optimization claims need arithmetic. If you cannot measure one input, label the estimate unquantified.

## Required inputs

| Input | Source |
|---|---|
| Runs per day | Actions Usage Metrics, workflow history, or the repo owner's stated run frequency |
| Current wall-clock minutes | Actions Performance Metrics or `/jobs` timing rollup from the toolkit |
| Candidate wall-clock minutes | Measured test branch run, not guessed |
| Current and candidate runner rates | Live rate card linked in [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost) |
| Failure rerun count | Performance Metrics failure rate plus run history |
| Queue time | Performance Metrics |

Do not use deprecated timing responses or public-repo `billable.total_ms`; the toolkit records those caveats in [`../actions-workflow-toolkit/SKILL.md`](../../actions-workflow-toolkit/SKILL.md#step-3--get-real-performance-data).

## Cost formulas

```text
per_run_current = current_wall_clock_minutes × current_rate
per_run_candidate = candidate_wall_clock_minutes × candidate_rate
per_run_savings = per_run_current - per_run_candidate
daily_savings = per_run_savings × runs_per_day
monthly_savings = daily_savings × observed_active_days_per_month
```

For reruns:

```text
rerun_waste_per_day = failed_or_canceled_retries_per_day × failed_attempt_minutes × runner_rate
```

For trigger filtering:

```text
filtered_savings_per_day = irrelevant_runs_per_day × current_wall_clock_minutes × runner_rate
```

For queue-time improvements:

```text
latency_saved = queue_minutes_before - queue_minutes_after
cost_saved = 0 unless the change also reduces billed run minutes or avoids reruns
```

Queue time hurts developer latency. It does not automatically mean billed runner minutes dropped. Keep those separate.

## Runner-sizing break-even

```text
rate_multiplier = candidate_rate / current_rate
speedup = current_wall_clock_minutes / candidate_wall_clock_minutes
```

- `speedup > rate_multiplier` means lower cost.
- `speedup = rate_multiplier` means cost-neutral latency improvement.
- `speedup < rate_multiplier` means higher cost for lower latency.

Use measured candidate runtime. A bigger runner can be cheaper, but only if the workload actually parallelizes.

## Two-layer report template

### Layer 1: screen-share summary

```md
The expensive target is `<workflow>`: it accounts for <measured share> of Actions minutes in the selected period.
The dominant cause is <queue time | run time | reruns | trigger waste>.
My first change is <lever> because <one-sentence reason>.
Estimated savings: <per-run saving × runs/day>, or unquantified because <missing input>.
```

### Layer 2: implementation detail

````md
#### <finding title>

- Evidence: `<file>:<line>` plus <dashboard/API source>.
- Diagnosis: <queue time | run time | rerun waste | trigger waste>.
- Scope: <repo YAML | org setting | product/test change>.
- Diff:

```diff
<exact diff>
```

- Citation: <relative docs-map link or live docs URL from toolkit>.
- Expected savings: <math>.
- Verification: `actionlint`, `zizmor` where relevant, and one measured run after the change.
````

## Honesty rules

- If you have no run frequency, do not annualize.
- If you have no candidate runtime, call runner-sizing savings hypothetical.
- If the win is latency only, do not call it cost savings.
- If the workflow is public and free to run, discuss latency and resource stewardship rather than bill reduction.
- If the required fix is org-level capacity, do not bury it under a YAML PR.
