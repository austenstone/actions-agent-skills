# Test corpus

Fixtures for validating the skills actually work. These are **not** real workflows — they live outside `.github/workflows/` so they never execute.

Run the corpus:

```bash
./verify.sh
```

## Why three fixtures

`clean.yml` is the most important file here. A security skill that flags a well-written workflow gets muted by the first developer who reads its output. The false-positive control is the product.

## Expected results

Verified against `actionlint 1.7.x` and `zizmor 1.29.0` with the default persona.

### `clean.yml` — the false-positive control

| tool | expected |
|---|---|
| actionlint | **0** |
| zizmor | **0** |

Anything above zero is either a regression in the fixture or a skill that's too aggressive. Investigate before shipping.

### `insecure.yml` — the security plane

zizmor: **14 findings across 8 rules**.

| rule | severity | why |
|---|---|---|
| `dangerous-triggers` | High | `pull_request_target` |
| `excessive-permissions` | High | `permissions: write-all` |
| `template-injection` ×2 | High | PR title and head ref interpolated into `run:` |
| `known-vulnerable-actions` ×2 | High | `tj-actions/changed-files@v35` (CVE-2025-30066) |
| `unpinned-uses` ×4 | High | tag/branch refs instead of SHAs, including the reusable-workflow call |
| `artipacked` ×2 | Medium | `persist-credentials` left on |
| `github-env` | High | untrusted value written to `$GITHUB_ENV` |
| `secrets-inherit` | Medium | `secrets: inherit` to an external reusable workflow |

actionlint finds only **3** here — two `expression` untrusted-input warnings and one `shellcheck`. It is not a security tool.

> The `leaky-caller` job deliberately references a **real** repo (`actions/starter-workflows`). zizmor's `ref-confusion` audit resolves remote refs over the API and **hard-fails the entire run** if the repo is unreachable — private, deleted, or typo'd. Workaround: `--offline`, or unset `GH_TOKEN`.

### `broken.yml` — the correctness plane

actionlint: **7 findings across 5 kinds**.

| kind | what it caught |
|---|---|
| `events` | `cron: '0 25 * * *'` — hour 25 doesn't exist |
| `runner-label` | `ubuntu-lastest` typo |
| `job-needs` | `needs: [does-not-exist]` |
| `expression` ×3 | `github.repositry`, undefined `steps.nope`, wrong matrix key `matrix.nodejs` |
| `shellcheck` | unquoted variable |

zizmor catches **none** of these. Every one is a runtime failure or a silently-never-runs job.

## The point

This is the argument for running both tools rather than reasoning about YAML:

- Neither tool subsumes the other. Their findings on `insecure.yml` and `broken.yml` barely intersect.
- A typo'd runner label and a cron hour of 25 are not things an LLM reliably notices by reading. `actionlint` knows the full label list and the cron grammar.
- `known-vulnerable-actions` requires a CVE database. No amount of reading the YAML gets you there.

## Adding fixtures

Extend `insecure.yml` or `broken.yml` rather than adding files, unless a rule needs a structure that conflicts with what's already there. Update the tables above and re-run `./verify.sh` — it asserts against the counts, so it will fail until you do.
