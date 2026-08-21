# Org Controls and Manual Review

Tools find workflow-local bugs. Recurrence prevention lives at repo, org, and enterprise policy layers. Use GitHub docs through [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md), especially secure use, OIDC, GITHUB_TOKEN, self-hosted runners, and artifact attestations.

## Allowed actions policy

Ask whether the org restricts actions to GitHub-owned, Marketplace-verified, or explicitly allowed actions. If anyone can add a random `uses: owner/repo@main`, SHA pinning becomes the last line of defense instead of the first.

Review outcome language:

> Recurrence control missing: this repo can still introduce arbitrary third-party actions. Add an allowed-actions policy and require SHA pins for third-party actions.

## Rulesets protecting workflow files

Protect `.github/workflows/**` with required review and status checks. Workflow edits are production infrastructure changes because they can alter token scopes, trigger contexts, and deployment paths.

Review outcome language:

> The workflow fix is easy to revert accidentally. Add a ruleset for `.github/workflows/**` so CI infrastructure changes require review.

## CODEOWNERS

Require owners for workflow files and reusable workflow entry points. Prefer owners who understand Actions security, not only application owners.

Example:

```text
.github/workflows/** @octo-org/actions-security
.github/actions/** @octo-org/actions-security
```

## Artifact attestations

For build and release workflows, check whether artifact attestations are enabled and verified before deployment. Cite the artifact attestation docs through [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md).

Review outcome language:

> The deploy job consumes build output without provenance verification. Add artifact attestations or rebuild from a trusted ref before deploy.

## Self-hosted runners on public repositories

Cite the self-hosted runner docs through [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md) and cite `self-hosted-runner` when zizmor flags it. Public fork PRs execute attacker-controlled code; non-ephemeral runners can carry compromise across jobs.

Safer posture checklist:

- Avoid self-hosted runners for public fork PRs.
- Prefer ephemeral, isolated runners for untrusted code.
- Split labels so privileged deploy runners are not routable by test workflows.
- Never put cloud credentials or private network reachability on general CI runners.

## OIDC trust policy design

Cite GitHub's [OIDC reference](https://docs.github.com/en/actions/reference/security/oidc). OIDC removes long-lived cloud secrets from GitHub, but the trust policy still decides which workflow identities can mint cloud credentials.

Review checklist:

- Trust one repo/workflow/environment shape, not an entire org wildcard.
- Bind production cloud roles to protected environments.
- Prefer exact `sub` matches for deployment jobs.
- Verify `aud` matches the intended cloud provider.
- Remove static cloud keys once OIDC is working.
