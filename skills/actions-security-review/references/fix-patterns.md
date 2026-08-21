# Fix Patterns

Use these when writing exact diffs for the Layer 2 report. For syntax and context semantics, cite the toolkit docs map instead of copying GitHub docs: [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md).

## Template injection

Why it is dangerous: GitHub expressions are expanded into the generated script before the runner shell executes it. If user-controlled text lands directly in `run:`, shell quoting inside the expression is not a security boundary. Cite the `template-injection` finding's `url`.

Untrusted surface to look for:

- `github.event.issue.title`, `github.event.issue.body`
- `github.event.pull_request.title`, `github.event.pull_request.body`
- `github.event.pull_request.head.ref`, `github.head_ref`
- `github.event.head_commit.message`, commit messages in event payloads
- `github.event.review.body`, comment and discussion bodies

Bad:

```yaml
permissions: {}

jobs:
  comment:
    runs-on: ubuntu-latest
    steps:
      - name: Use PR title
        run: |
          echo "Reviewing ${{ github.event.pull_request.title }}"
          ./scripts/check-title.sh "${{ github.event.pull_request.title }}"
```

Good:

```yaml
permissions: {}

jobs:
  comment:
    runs-on: ubuntu-latest
    steps:
      - name: Use PR title
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: |
          echo "Reviewing $PR_TITLE"
          ./scripts/check-title.sh "$PR_TITLE"
```

Better when the value is only used by an action input:

```yaml
permissions: {}

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@<sha-from-zizmor-fix-title> # v7
        with:
          script: |
            const title = context.payload.pull_request.title
            core.info(`Reviewing ${title}`)
```

## GITHUB_ENV and GITHUB_OUTPUT injection

Cite the GitHub variables/environment-files page via [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md). Cite `github-env` for `GITHUB_ENV` and `GITHUB_PATH` findings. `GITHUB_OUTPUT` misuse may only show up as `template-injection` or manual review, so do not imply zizmor proves every output write safe. Do not let untrusted input choose an environment/output name. Avoid writing untrusted multiline content into environment files unless it is framed as data and consumed as data.

Bad:

```yaml
steps:
  - name: Export user input
    run: |
      echo "${{ github.event.issue.title }}" >> "$GITHUB_ENV"
      echo "result=${{ github.event.issue.body }}" >> "$GITHUB_OUTPUT"
```

Good:

```yaml
steps:
  - name: Keep user input in a file
    env:
      ISSUE_TITLE: ${{ github.event.issue.title }}
      ISSUE_BODY: ${{ github.event.issue.body }}
    run: |
      mkdir -p review-data
      printf '%s\n' "$ISSUE_TITLE" > review-data/title.txt
      printf '%s\n' "$ISSUE_BODY" > review-data/body.txt
```

If a later step truly needs an output, make the output name static and encode or validate the value before writing it:

```yaml
steps:
  - id: issue
    env:
      ISSUE_TITLE: ${{ github.event.issue.title }}
    run: |
      title_b64=$(printf '%s' "$ISSUE_TITLE" | base64 | tr -d '\n')
      echo "title_b64=$title_b64" >> "$GITHUB_OUTPUT"
```

## Permissions

Default-deny at workflow scope, then grant only what each job uses. Cite the GITHUB_TOKEN page through [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md).

Bad. Treat `permissions: write-all` as the same smell, even if a scanner does not call it out.

```yaml
permissions:
  contents: write
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha-from-zizmor-fix-title> # v7
        with:
          persist-credentials: false
      - run: npm test
  package:
    runs-on: ubuntu-latest
    steps:
      - run: npm pack
```

Good:

```yaml
permissions: {}

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<sha-from-zizmor-fix-title> # v7
        with:
          persist-credentials: false
      - run: npm test
  package:
    runs-on: ubuntu-latest
    steps:
      - run: npm pack
```

## Unpinned actions

Use the SHA from zizmor `fixes[].title`. Do not invent one. The tag-to-SHA trust argument belongs in Layer 1; the exact SHA diff belongs in Layer 2.

Bad:

```yaml
steps:
  - uses: docker/login-action@v4
```

Good shape:

```yaml
steps:
  - uses: docker/login-action@<sha-from-zizmor-fix-title> # v3
```

## Known vulnerable actions

Treat `known-vulnerable-actions` as urgent when the action handles secrets, tokens, artifacts, or source code. The canonical example is [`tj-actions/changed-files` CVE-2025-30066](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3), where vulnerable versions allowed secrets to be discovered through Actions logs. The GitHub advisory is the source for affected and patched versions.

Bad:

```yaml
steps:
  - uses: tj-actions/changed-files@v45
```

Good shape:

```yaml
steps:
  - uses: tj-actions/changed-files@<fixed-version-or-sha-from-zizmor>
```

## Checkout credentials and artifacts

Cite `artipacked` when zizmor flags it. The behavioral risk is that disabling persisted credentials can break later `git push` steps, so mark this as unsafe unless the workflow never pushes.

Bad:

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: actions/upload-artifact@v7
    with:
      name: workspace
      path: .
```

Good when no later step pushes:

```yaml
steps:
  - uses: actions/checkout@<sha-from-zizmor-fix-title> # v7
    with:
      persist-credentials: false
  - uses: actions/upload-artifact@<sha-from-zizmor-fix-title> # v4
    with:
      name: workspace
      path: .
```

## Reusable workflow secrets

Cite `secrets-inherit` when zizmor flags it and cite reusable workflow docs through [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md).

Bad:

```yaml
permissions: {}

jobs:
  deploy:
    uses: octo-org/platform/.github/workflows/deploy.yml@<sha-from-zizmor-fix-title> # main
    secrets: inherit
```

Good:

```yaml
permissions: {}

jobs:
  deploy:
    uses: octo-org/platform/.github/workflows/deploy.yml@<sha-from-zizmor-fix-title> # main
    secrets:
      deploy_token: ${{ secrets.PRODUCTION_DEPLOY_TOKEN }}
```

## GitHub App installation tokens

Cite `github-app` when zizmor flags it and cite the finding URL. The risk is not "GitHub Apps are bad"; the risk is issuing an installation token with too much lifetime, repository reach, or permission reach for the job.

Fix direction:

- Keep token revocation enabled unless the workflow has a specific post-job need.
- Scope the token to the exact repositories the job touches.
- Request only the permissions needed for the operation.
- Prefer `GITHUB_TOKEN` when its scoped job permissions are enough.

## Misfeatures

Cite `misfeature` when zizmor flags it and cite the finding URL. Treat it as hardening unless it combines with a privileged path. Replace the feature with the remediation suggested by the audit docs, such as moving package installation out of setup-action inputs and into an explicit, auditable install step.

## OIDC trust policy mistakes

Use OIDC instead of long-lived cloud keys, then review the cloud trust policy. Wildcard `sub` matching turns a good design into broad repo or org trust. Cite GitHub's [OIDC reference](https://docs.github.com/en/actions/reference/security/oidc).

Bad trust shape:

```json
{
  "token.actions.githubusercontent.com:sub": "repo:octo-org/*"
}
```

Good trust shape:

```json
{
  "token.actions.githubusercontent.com:sub": "repo:octo-org/octo-repo:environment:production"
}
```
