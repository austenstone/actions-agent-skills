# Savings Math and Report Shape

Optimization claims need arithmetic. If you cannot measure one input, label the estimate unquantified.

## Required inputs

| Input | Source |
|---|---|
| Runs per day | Actions Usage Metrics, workflow history, or the repo owner's stated run frequency |
| Current latency | Actions Performance Metrics or `/jobs` critical-path timing from the toolkit |
| Candidate latency | Measured test branch run, not guessed |
| Current billable job minutes by runner SKU | Actions Usage Metrics, or `/jobs` durations summed by runner label/SKU with the pricing page's job-duration rounding rule |
| Candidate billable job minutes by runner SKU | Measured test branch run, calculated the same way as current |
| Current and candidate runner rates | Live rate card linked in [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost) |
| Failure rerun count | Performance Metrics failure rate plus run history |
| Queue time | Performance Metrics |

Do not use deprecated timing responses or public-repo billable fields; the toolkit records those caveats in [`../actions-workflow-toolkit/SKILL.md`](../../actions-workflow-toolkit/SKILL.md#step-3--get-real-performance-data). Use workflow wall-clock for latency, not cost, when jobs run in parallel.

## Cost formulas

```text
per_run_current = sum(current_rounded_job_minutes_by_sku × current_rate_by_sku)
per_run_candidate = sum(candidate_rounded_job_minutes_by_sku × candidate_rate_by_sku)
per_run_savings = per_run_current - per_run_candidate
daily_savings = per_run_savings × runs_per_day
monthly_savings = daily_savings × observed_active_days_per_month
```

For reruns:

```text
rerun_waste_per_day = failed_or_canceled_retries_per_day × sum(failed_attempt_rounded_job_minutes_by_sku × runner_rate_by_sku)
```

For trigger filtering:

```text
filtered_savings_per_day = irrelevant_runs_per_day × sum(current_rounded_job_minutes_by_sku × runner_rate_by_sku)
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
billable_minute_reduction = current_rounded_job_minutes / candidate_rounded_job_minutes
latency_speedup = current_latency / candidate_latency
```

- `billable_minute_reduction > rate_multiplier` means lower cost.
- `billable_minute_reduction = rate_multiplier` means cost-neutral latency improvement.
- `billable_minute_reduction < rate_multiplier` means higher cost for lower latency.

Use measured candidate runtime. A bigger runner can be cheaper, but only if the workload actually parallelizes and reduces rounded billable job minutes enough to beat the rate multiplier.

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
- If the workflow uses free standard runners in a public repository, discuss latency and resource stewardship rather than bill reduction. Larger runners are still a billing conversation; cite the live rate card.
- If the required fix is org-level capacity, do not bury it under a YAML PR.
