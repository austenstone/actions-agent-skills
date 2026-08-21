# Privileged Triggers

Use this for `pull_request_target`, `workflow_run`, and the classic pwn-request pattern. Cite GitHub's [`pull_request_target` security guidance](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target) and the `dangerous-triggers` finding URL.

## The model

`pull_request_target` and `workflow_run` are dangerous when privileged base-repo credentials touch attacker-controlled code, artifacts, cache entries, or text. The trigger is not the bug by itself; the data flow is the bug.

## `pull_request_target`

Current checkout behavior matters: `actions/checkout` v7+ defaults to the base branch for `pull_request_target`; `allow-unsafe-pr-checkout` is the explicit opt-out. The docs-map calls this out in [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md). Grep for the opt-out and for manual `ref:` values that recreate the old footgun.

High-risk:

```yaml
on:
  pull_request_target:

permissions:
  contents: write

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha-from-zizmor-fix-title> # v7
        with:
          allow-unsafe-pr-checkout: true
      - run: npm install && npm test
```

Lower-risk shape:

```yaml
on:
  pull_request_target:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@<sha-from-zizmor-fix-title> # v7
        with:
          script: |
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number,
              labels: ['needs-review']
            })
```

Triage questions:

- Does it checkout PR head, use `allow-unsafe-pr-checkout`, or set `ref:` from PR head data?
- Does it execute dependency install, build, test, script, composite action, or local action from PR content?
- Does it expose write token scopes, repository secrets, cloud credentials, or deployment environments?
- Does it write comments/labels only, with narrow permissions and no PR-head execution?

## `workflow_run`

The risky pattern is a privileged downstream workflow consuming untrusted artifacts or code from an unprivileged upstream workflow.

High-risk:

```yaml
on:
  workflow_run:
    workflows: [CI]
    types: [completed]

permissions:
  contents: write
  actions: read

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@<sha-from-zizmor-fix-title> # v4
        with:
          name: artifact
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ github.token }}
          path: artifact
      - run: ./artifact/deploy.sh
```

Safer shape:

```yaml
on:
  workflow_run:
    workflows: [CI]
    types: [completed]

permissions:
  contents: read

jobs:
  inspect:
    runs-on: ubuntu-latest
    steps:
      - name: Verify upstream conclusion only
        env:
          CONCLUSION: ${{ github.event.workflow_run.conclusion }}
        run: test "$CONCLUSION" = success
```

Triage questions:

- Did the upstream workflow run on fork PR code?
- Are artifacts treated as data or executed as code?
- Is there a signature, checksum, provenance, or trusted rebuild before publish/deploy?
- Could an attacker choose artifact names, paths, scripts, or cache keys?

## False-positive boundary

Do not report a privileged trigger as a finding when the workflow never executes PR-head code, never consumes untrusted artifacts as code, has minimum token scopes, and performs a bounded metadata operation. Mention that zizmor warned on the trigger if it did, but downgrade or close it if the data flow is safe.
