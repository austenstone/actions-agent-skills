---
name: actions-architecture-review
description: "Reviews the shape of an entire GitHub Actions estate across many repos or a monorepo, finding duplicated jobs, migration debt, missing governance, event-model mistakes, and platform refactors that no per-file linter can see. Use when: review our CI architecture, should this be a reusable workflow or composite action, our workflows are duplicated across repos, monorepo CI design, standardize CI across teams, workflow governance, we migrated from Jenkins and it is a mess, or CI/CD platform design. Load alongside actions-workflow-toolkit for workflow discovery, tool validation, safety rules, and live GitHub Actions documentation links."
---

# Actions Architecture Review

Load [`../actions-workflow-toolkit/SKILL.md`](../actions-workflow-toolkit/SKILL.md) first. This skill does not replace `actionlint` or `zizmor`; it explains what they cannot see across files and repos.

## Thesis

Enterprise Actions estates usually fail in one of three shapes. Diagnose the shape before recommending a fix:

1. **The monolith**: one enormous migrated pipeline, usually a Jenkinsfile or `.gitlab-ci.yml` translated 1:1.
2. **Ungoverned sprawl**: every team invented CI/CD separately, so the same deploy logic drifts across repos.
3. **The monorepo blast radius**: every PR runs everything because no one designed change detection.

The remedies conflict. Do not prescribe a central platform refactor for a small repo. Do not split a monolith into reusable workflows before you understand the dependency graph. Do not optimize caches when the architecture problem is queue contention.

## Phase 1: Inventory

Start with the estate boundary:

- **Single repo**: enumerate `.github/workflows/*.{yml,yaml}` locally or through `gh` using the toolkit's remote-read pattern.
- **Organization**: inventory all workflow files, then group by repo, event, job name, runner, permissions, environment, and repeated job bodies.
- **Monorepo**: inventory workflows plus top-level package/service directories and path filters.

Use concrete commands from [`references/inventory-and-classification.md`](references/inventory-and-classification.md). For every workflow file you inspect directly, run the toolkit validation first. Architecture findings should sit on top of valid YAML, not compensate for broken YAML.

## Phase 2: Classify

Classify the dominant failure shape. Mixed estates exist, but force a primary diagnosis.

| Shape | Screen-share symptom | Primary evidence | Usual remedy |
|---|---|---|---|
| Monolith | "One workflow is the old pipeline with YAML syntax." | Huge file, sequential `needs:`, broad triggers, rebuilds unrelated code | Decompose by real dependency boundaries |
| Ungoverned sprawl | "A security fix requires PRs across dozens of repos." | Near-identical jobs, drifting action versions, no shared workflow contract | Central reusable workflows, versioned rollout, governance |
| Monorepo blast radius | "Developers wait for tests for code they did not touch." | Full matrices on every PR, weak or absent path selection, required-check deadlocks | Selective builds, dynamic matrices, merge queue design |

Detection details and commands live in [`references/inventory-and-classification.md`](references/inventory-and-classification.md).

## Phase 3: Recommend

Architecture changes are production migrations. Recommend a sequence, not a wish list.

1. **Stabilize**: validate current workflows, identify required checks, and avoid renaming checks until branch protection impact is known.
2. **Extract one seam**: pick the smallest high-duplication or high-waste area that proves the pattern.
3. **Canary**: land it in one repo or one service path.
4. **Cohort**: expand to similar repos/services after the first failure modes are known.
5. **Default**: make the new pattern the documented path and gate new exceptions.
6. **Deprecate**: announce a date, keep old workflows alive until consumers have a safe migration path.

Use [`references/refactoring-playbooks.md`](references/refactoring-playbooks.md) for the refactor order by shape.

## Architecture decisions to make explicitly

- Reusable workflow vs composite action vs custom action: use [`references/decision-matrices.md`](references/decision-matrices.md).
- Governance: central `.github` or platform repo, CODEOWNERS, rulesets on `.github/workflows/**`, allowed-actions policy, required workflows when available, and a versioning stance.
- Event model: `pull_request`, `pull_request_target`, `merge_group`, `workflow_run`, `repository_dispatch`, and `workflow_dispatch` are trust-boundary choices, not just trigger syntax. Use the toolkit docs map for live event docs: [`../actions-workflow-toolkit/references/docs-map.md`](../actions-workflow-toolkit/references/docs-map.md).
- CI/CD separation: build once, deploy many; promote artifacts; gate environments; scope OIDC by environment.
- Scale limits: fetch live limits through the toolkit docs map. The reusable workflow nesting fact worth stating is **10 levels total**: top-level caller plus up to 9 nested workflows. Older docs said 4. The current docs also cap one caller workflow file at **50 unique reusable workflows**, including nested calls. See [reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) and [reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations).

## Output format

Always produce two layers.

**Layer 1: organizational consequence.** Plain language, screen-shareable, no tool jargon.

> The same deploy job is copy-pasted across 23 repos. A credential-rotation or runner-image fix is 23 PRs, and several repos will drift before the rollout finishes.

**Layer 2: evidence and refactor.** Specific files, commands, proposed sequence, and citations.

> `payments/.github/workflows/deploy.yml` and `billing/.github/workflows/deploy.yml` have the same normalized `deploy` job body except environment name. Extract `org/.github/.github/workflows/deploy-service.yml@v1`, canary in `payments`, then migrate the billing cohort.

## Restraint

If the estate has three small workflows, no duplication, clear ownership, and tolerable run time, say: **this is fine, leave it alone.** Architecture recommendations are expensive. The review earns trust by not manufacturing platform work.
