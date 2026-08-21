# Decision matrices

Fetch live syntax and capability docs through [`../../actions-workflow-toolkit/references/docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md) before citing a customer-facing answer.

## Reusable workflow vs composite action vs custom action

| Choose | When it is right | Capability shape | Avoid when |
|---|---|---|---|
| Reusable workflow | You are standardizing a whole job or pipeline contract across repos | Defines jobs, permissions, environments, outputs, runner choices, services, job timeouts, matrices, and `workflow_call` inputs/secrets inside the called workflow. The caller job can use only the supported call-job keys, including `uses`, `with`, `secrets`, `strategy`, `needs`, `if`, `concurrency`, and `permissions`. It cannot insert caller steps around the call or set caller-side `runs-on`/`environment`. Reusable workflow nesting is **10 levels total**: caller plus up to 9 nested workflows. A single caller workflow file can call **50 unique reusable workflows**, including nested calls. Sources: [reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) and [reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations). | You need to insert logic between arbitrary existing steps inside a job, or the caller must own the runner/environment choice. |
| Composite action | You are standardizing a step sequence inside an existing job | Runs as one `uses:` step under the caller job's runner, permissions, token, shell, timeout, and environment. It can contain `run` and `uses` steps, step-level `if`, `env`, `working-directory`, and outputs. It cannot define jobs, runners, services, matrices, job-level permissions, or environments, and the `secrets` context is not available inside a composite action. Pass secrets explicitly as inputs or environment variables from the caller. Composite actions can be nested to have up to **10 composite actions in one workflow**. Sources: [reusing workflow configurations](https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations), [metadata syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax#runs-for-composite-actions), and [contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#secrets-context). | You need multiple jobs, different runners, environments, services, matrix fan-out, or job-level permissions. |
| JavaScript or Docker action | You need reusable code, richer validation, tests, dependencies, or distribution outside one org | Encapsulates behavior behind `action.yml`; the caller sees one `uses:` step. Use the metadata docs in the [toolkit docs map](../../actions-workflow-toolkit/references/docs-map.md). | The problem is CI platform shape. A custom action cannot fix repo sprawl by itself. |
| Workflow template / starter workflow | You want a good starting file when teams create new workflows | Seeds a workflow file into the consumer repo. It can reference reusable workflows, but the template itself is copied and then owned by the repo. Sources: [workflow templates](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations#workflow-templates) and [reusing workflow configurations](https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations#workflow-templates). | You need patch-once central governance. A copied template drifts like any other local workflow. |

## Rule of thumb

- If the reusable unit needs `runs-on`, `permissions`, `environment`, `services`, `strategy`, job `timeout-minutes`, or multiple jobs, it is a **reusable workflow**.
- If the reusable unit must appear between `checkout` and `test` in many different jobs, it is a **composite action**.
- If the reusable unit is software with logic, dependencies, and tests, it is a **custom action**.
- If the unit is only a recommended starting point for new repos, it is a **workflow template**. Do not sell templates as centralized maintenance.

## Secrets through reusable workflow nesting

`secrets: inherit` only passes secrets to the directly called workflow. In a chain `A > B > C`, `C` receives `A`'s secrets only if `A` passes them to `B` and `B` passes them again to `C`. Source: [passing secrets to nested workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#passing-secrets-to-nested-workflows).

## Reusable workflow caller example

```yaml
name: ci

on:
  pull_request:

permissions:
  contents: read

jobs:
  node-ci:
    uses: org/actions-platform/.github/workflows/node-ci.yml@v1
    with:
      node-version: "22"
    secrets: inherit
```

## Reusable workflow callee example

```yaml
name: node-ci

on:
  workflow_call:
    inputs:
      node-version:
        required: true
        type: string

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: ${{ inputs.node-version }}
      - run: npm ci
      - run: npm test
```

## Composite action caller example

```yaml
name: unit

on:
  pull_request:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: org/actions-platform/setup-node-workspace@v1
        with:
          node-version: "22"
      - run: npm test
```

## Governance layer

| Control | What it prevents | Architecture guidance |
|---|---|---|
| Central workflow repo | Copy-pasted CI contracts | Prefer a repo the platform team owns. The special `.github` repo is fine when the org wants discoverability. |
| CODEOWNERS on `.github/workflows/**` | Silent CI/CD ownership drift | Make workflow ownership explicit before centralizing templates. |
| Rulesets protecting workflow paths | Unreviewed workflow changes | Protect workflow files as production infrastructure, not repo decoration. |
| Allowed-actions policy | Random marketplace drift | Pair allowlists with a documented exception path or teams will route around them. |
| Required workflows or required checks | Missing baseline controls | Verify current org-plan support in GitHub docs before promising this; use the [docs map](../../actions-workflow-toolkit/references/docs-map.md) as the entry point. |

## Versioning shared workflows

| Reference style | Consumer experience | Platform-team experience | Use when |
|---|---|---|---|
| SHA | Maximum immutability | Every fix needs consumer PRs | Regulated or high-risk deployment paths. |
| Tag | Stable contract with explicit upgrades | Requires release discipline | Default for reusable workflow products. |
| Branch | Consumers get fixes without PRs | A bad merge can break everyone | Internal canaries or low-risk early rollout only. |

The tension is real: consumers want stability, platform teams want to patch once. Resolve it by publishing tags, keeping a canary branch, and documenting support windows.

## Event model as architecture

| Event | Design meaning | Common architecture mistake |
|---|---|---|
| `pull_request` | Evaluate proposed code with fork-aware boundaries | Using it for privileged deployment decisions. |
| `pull_request_target` | Run trusted base-repo workflow logic in response to untrusted PR activity | Treating it as a faster `pull_request`. Load the security docs from the toolkit before recommending it. |
| `merge_group` | Validate the exact merge-queue candidate | Forgetting it, then wondering why required checks never satisfy merge queue. |
| `workflow_run` | Chain from one workflow's result to another trust boundary | Accidentally deploying artifacts rebuilt from a different ref. `workflow_run` can access secrets and write tokens even if the previous workflow was unprivileged, and it cannot chain more than three levels. Source: [events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run). |
| `repository_dispatch` | External system asks GitHub to run a workflow | Building an unaudited API surface with no event schema. |
| `workflow_dispatch` | Human-triggered operation | Treating manual runs as governance instead of adding environment approvals. |
| `paths` / `paths-ignore` | Skip entire `push` or `pull_request` workflows before they start | Making a path-filtered workflow a required check. Skipped workflows stay pending and block merge. Source: [workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onpushpull_requestpull_request_targetpathspaths-ignore). |

Use the live event docs from the [toolkit docs map](../../actions-workflow-toolkit/references/docs-map.md). The event choice decides which actor, ref, token, and secrets model the workflow gets.
