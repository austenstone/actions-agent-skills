# Report Template

Use this exact two-layer shape. Layer 1 is for humans in a meeting. Layer 2 is for the engineer applying diffs.

## Layer 1 — consequence summary

```md
## Security review summary

1. Critical: Fork PR code can run with base-repo write permissions in `release.yml`. A malicious PR can turn CI into a repo-write primitive.
2. High: `deploy.yml` runs a known-vulnerable third-party action that can expose secrets in logs.
3. High: Several third-party actions are tag-pinned, so their code can change without a workflow diff.
4. Medium: The default GITHUB_TOKEN scopes are broader than the jobs need.

Clean checks: actionlint found no expression or workflow syntax errors. No self-hosted runners were reachable from public PR triggers.
Not checked: org allowed-actions policy and cloud OIDC trust policy were not available from this checkout.
```

Rules:

- Lead with consequence, not rule ID.
- Keep scanner internals out of Layer 1.
- Include clean checks. Silence is ambiguous.
- Include skipped checks. Hidden gaps are worse than known gaps.

## Layer 2 — remediation evidence

````md
### 1. Fork PR code can run with base-repo write permissions

- Location: `.github/workflows/release.yml:23`
- Rule: `dangerous-triggers`
- Severity/confidence: High/High
- Citation: https://docs.zizmor.sh/audits/#dangerous-triggers
- GitHub docs: https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target
- Auto-apply: no, trigger/data-flow redesign

```diff
 on:
-  pull_request_target:
+  pull_request:

 permissions:
-  contents: write
+  contents: read
```

Why: this job checks out PR-controlled code and executes it with base-repo privileges. Move tests to `pull_request`; keep only bounded metadata writes on `pull_request_target` if needed.
````

## False-positive notes

Use this section to close noisy findings explicitly:

```md
### Closed: `pull_request_target` in `.github/workflows/label.yml`

Not a finding. The workflow does not checkout PR head, does not execute PR content, grants only `pull-requests: write`, and only applies labels through the API. Keep it under review if new steps are added.
```

A clean workflow must produce a clean report:

```md
## Security review summary

No security findings from zizmor. No actionlint findings. Manual review did not find privileged-trigger data-flow issues, public self-hosted runner exposure, `secrets: inherit`, or OIDC wildcard trust patterns in the files available.

Not checked: org allowed-actions policy, repo rulesets, CODEOWNERS enforcement, and cloud-side OIDC trust policy were not available from the workflow checkout.
```
