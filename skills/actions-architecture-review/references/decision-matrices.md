# Decision matrices

Fetch live syntax and capability docs through [`../../actions-workflow-toolkit/references/docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md) before citing a customer-facing answer.

## Reusable workflow vs composite action vs custom action

| Choose | When it is right | Capability shape | Avoid when |
|---|---|---|---|
| Reusable workflow | You are standardizing a whole job or pipeline contract across repos | Defines jobs, permissions, environments, outputs, runner choices, and `workflow_call` inputs/secrets. It runs at the job boundary and can use `secrets: inherit`. Reusable workflow nesting is **10 levels total**: caller plus up to 9 nested workflows. Source: [reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows). | You need to insert logic between arbitrary existing steps inside a job. |
| Composite action | You are standardizing a step sequence inside an existing job | Runs as steps under the caller job's runner, permissions, token, shell, and environment. Secrets are passed as inputs or inherited through the job environment, not with a `secrets:` block. Composite actions can be nested 10 levels; verify the current metadata and limits docs through the [toolkit docs map](../../actions-workflow-toolkit/references/docs-map.md) before citing externally. | You need multiple jobs, different runners, environments, or job-level permissions. |
| JavaScript or Docker action | You need reusable code, richer validation, tests, dependencies, or distribution outside one org | Encapsulates behavior behind `action.yml`; the caller sees one `uses:` step. Use the metadata docs in the [toolkit docs map](../../actions-workflow-toolkit/references/docs-map.md). | The problem is CI platform shape. A custom action cannot fix repo sprawl by itself. |

## Rule of thumb

- If the reusable unit needs `runs-on`, `permissions`, `environment`, `services`, `strategy`, or multiple jobs, it is a **reusable workflow**.
- If the reusable unit must appear between `checkout` and `test` in many different jobs, it is a **composite action**.
- If the reusable unit is software with logic, dependencies, and tests, it is a **custom action**.

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
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
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
      - uses: actions/checkout@v5
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
| `workflow_run` | Chain from one workflow's result to another trust boundary | Accidentally deploying artifacts rebuilt from a different ref. |
| `repository_dispatch` | External system asks GitHub to run a workflow | Building an unaudited API surface with no event schema. |
| `workflow_dispatch` | Human-triggered operation | Treating manual runs as governance instead of adding environment approvals. |

Use the live event docs from the [toolkit docs map](../../actions-workflow-toolkit/references/docs-map.md). The event choice decides which actor, ref, token, and secrets model the workflow gets.
