---
name: actions-optimization
description: CI is slow, reduce Actions minutes, cut CI costs, why is my cache not hitting, speed up my workflow, runner sizing, workflow takes too long, reduce GitHub Actions bill, diagnose queue time, fix flaky reruns, optimize matrix builds, tune Docker layer caching, and right-size GitHub-hosted runners. This optimization playbook measures first, separates queue time from run time from failure-rate-driven reruns, then chooses the highest-ROI GitHub Actions lever with exact YAML diffs and live citations. Load it with actions-workflow-toolkit for tooling, safety contract, performance-data mechanics, API commands, JSON shapes, and documentation URL lookup.
---

# Actions Optimization

Load [`actions-workflow-toolkit`](../actions-workflow-toolkit/SKILL.md) first. This file is only the optimization playbook: diagnosis, lever selection, savings math, and YAML fix patterns.

## Guardrails before recommending anything

- Do not remove a required check. A fast CI that stopped validating is a regression.
- Do not drop matrix legs that represent a real support commitment. Mark those as product decisions, not optimization wins.
- Do not reduce parallelism unless measured fixed overhead is larger than the work saved.
- Split recommendations into repo-editable YAML changes and org-level settings changes. Runner groups, spending controls, hosted-runner policy, and enterprise concurrency are not PR diffs.
- Cite live docs through the toolkit docs map, not memory: [`docs-map.md`](../actions-workflow-toolkit/references/docs-map.md).

## Phase 1: Measure

Start with data, not grep. Static YAML review tells you possible waste; metrics tell you where the bill and latency actually are.

| Signal | Source | What it means | Next move |
|---|---|---|---|
| High average queue time | Actions Performance Metrics via toolkit | Capacity or concurrency problem, not workflow inefficiency | Do not refactor YAML first. Check runner availability, org concurrency, `max-parallel`, and superseded-run cancellation. |
| High average run time | Actions Performance Metrics, then `/jobs` API | Critical path is inside the job | Use step timings to choose cache, checkout, Docker, matrix, or runner-sizing fixes. |
| High failure rate | Actions Performance Metrics | Reruns are multiplying cost | Fix flake, environment instability, dependency fetch failures, or fail-fast behavior before tuning runtime. |
| Minutes concentrated in one workflow/repo | Actions Usage Metrics | The expensive target is known | Optimize that workflow first, even if another file looks uglier. |
| One slow step dominates a run | `/actions/runs/{id}/jobs` through toolkit | Step-level bottleneck | Apply the lever that matches that step. |

Toolkit mechanics and caveats live in [`../actions-workflow-toolkit/SKILL.md#get-real-performance-data`](../actions-workflow-toolkit/SKILL.md#step-3--get-real-performance-data). Do not use deprecated run timing data or public-repo `billable.total_ms` for cost math; use wall-clock and the live rate card referenced by the toolkit.

## Phase 2: Diagnose

Use this order. It prevents the classic mistake: optimizing YAML while jobs are just waiting for capacity.

```text
1. Queue time high?
   yes -> capacity/concurrency diagnosis.
          repo YAML levers: concurrency cancel-in-progress, max-parallel shaping.
          org levers: runner availability, larger runner pools, concurrency policy.
          stop calling this a workflow optimization until queue is explained.

2. Failure rate high?
   yes -> rerun-waste diagnosis.
          fix flakes, dependency instability, test isolation, fail-fast policy.
          estimate cost as failed attempts + reruns, not successful run time.

3. Usage concentrated in a workflow triggered too often?
   yes -> trigger/path diagnosis.
          add safe path filters or monorepo change detection.
          avoid required-check deadlocks.

4. Run time high after queue and failure are explained?
   yes -> critical-path diagnosis from job step timings.
          dependency install slow -> package-manager cache.
          Docker build slow -> buildx gha or registry cache, layer ordering.
          checkout slow -> sparse checkout, LFS/submodule scrutiny.
          CPU-bound tests -> runner sizing, matrix, or ARM compatibility.
          many tiny jobs -> job graph consolidation.
```

Detailed branching logic: [`references/decision-tree.md`](references/decision-tree.md).

## Phase 3: Fix, ranked by usual ROI

1. **Cancel superseded PR runs.** Best first PR for noisy repos. Use `concurrency` groups that include event type and do not cancel default-branch runs. Syntax citation: [`docs-map.md#performance-and-cost`](../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).
2. **Move compatible Linux jobs to ARM64 standard runners.** Often a one-line win. Verify native dependencies and Docker image architecture first. Current labels and specs: [`docs-map.md#performance-and-cost`](../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).
3. **Check `ubuntu-latest` visibility behavior.** The same label maps to different hosted-runner capacity for public vs private repos. Do not copy the specs; cite the live runner reference: [`docs-map.md#performance-and-cost`](../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).
4. **Stop running expensive workflows on irrelevant changes.** Use path filters or dynamic monorepo matrices, but handle required-status-check deadlocks. Trigger docs: [`docs-map.md#syntax-and-semantics`](../actions-workflow-toolkit/references/docs-map.md#syntax-and-semantics).
5. **Cache package-manager stores, not random build directories.** Prefer `setup-*` built-in cache inputs when they cover the ecosystem; use `actions/cache` for custom paths. Cache behavior citation: [`docs-map.md#performance-and-cost`](../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).
6. **Right-size runners with arithmetic.** Larger runners can be cheaper only when measured speedup beats the rate multiplier. They have separate billing behavior from included minutes, so cite the current docs before recommending them: [`docs-map.md#performance-and-cost`](../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).
7. **Shape the matrix.** Use `fail-fast`, `max-parallel`, and dynamic `fromJSON` matrices for selective monorepo builds. Matrix docs: [`docs-map.md#performance-and-cost`](../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).
8. **Fix job graph shape.** Every job has VM, checkout, and dependency overhead. Splitting only wins when branches are long and independent.
9. **Reduce checkout and Docker tax.** Keep checkout shallow unless history is required, use sparse checkout, scrutinize LFS/submodules, tune `buildx` cache scopes, and switch to registry cache when GitHub cache limits are the bottleneck. Checkout/action and Docker references start from [`docs-map.md`](../actions-workflow-toolkit/references/docs-map.md).

Exact before/after YAML: [`references/fix-patterns.md`](references/fix-patterns.md). Savings method and report shape: [`references/savings-math.md`](references/savings-math.md).

## Required output

Return two layers.

**Layer 1: screen-share summary**

Plain language, quantified when data exists:

> Roughly 40% of measured CI minutes are from `ci.yml`, and most of that is reruns from failed PR attempts. The first fix is flake reduction plus canceling superseded PR runs, not runner sizing.

If run frequency is unknown, say the estimate is unquantified. Do not invent runs/day.

**Layer 2: implementation detail**

For each recommendation:

```text
Finding: Superseded PR runs are still executing.
Evidence: .github/workflows/ci.yml:1 plus Actions Usage Metrics for ci.yml.
Change: add workflow-level concurrency scoped to event + PR/ref.
Diff: <exact diff>
Citation: ../actions-workflow-toolkit/references/docs-map.md#performance-and-cost
Expected savings: per-run saving × measured runs/day. Frequency missing -> unquantified.
Scope: repo YAML change.
```
