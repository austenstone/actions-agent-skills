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
- Rank by exploitability and blast radius, not raw scanner severity.
- Keep scanner internals out of Layer 1.
- Include clean checks. Silence is ambiguous.
- Include skipped checks. Hidden gaps are worse than known gaps.
- First-party action tag pins, low-confidence cache-poisoning, and `artipacked` hygiene belong in grouped hardening unless they combine with an exploit path.

If online zizmor audits hard-failed and the successful rerun used `--no-online-audits` or `--offline`, say so:

```md
Skipped checks: zizmor network-dependent audits were skipped after the online pass hard-failed, so this review does not cover impostor commits, ref confusion, known-vulnerable actions, or stale action refs.
```

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

## Scale mode shape

Use this when the repo has more than 25 workflows or more than 100 total findings:

```md
## Security review summary

Scale mode: 151 workflows and 885 scanner findings. Raw findings are grouped below; the appendix has the scanner rows.

### Fix first

1. `release-*` workflows: privileged publish jobs consume PR-controlled artifacts. Redesign the trigger/data flow.
2. `deploy-*` workflows: user-controlled release text reaches `run:`. Move expressions into `env:` and quote shell variables.

### Cohorts

- Third-party action pinning: 42 findings across 9 owners. Start with untrusted or abandoned owners used in release/deploy paths.
- First-party `actions/*` tag pins: grouped hardening item. Not a top finding without an exploit path.
- Reusable workflow secret inheritance: repeated across platform workflows. Treat as governance work on the reusable workflow contract.

### Appendix

Raw scanner rows omitted from the meeting summary; include them here or link the artifact.
```
