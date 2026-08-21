# Inventory and classification

Use this after loading [`../../actions-workflow-toolkit/SKILL.md`](../../actions-workflow-toolkit/SKILL.md). The toolkit owns workflow discovery basics, validation, safety, and canonical docs links.

## Local repo inventory

```bash
find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort
```

Summarize shape without reading every line manually:

```bash
for f in .github/workflows/*.{yml,yaml}; do
  [ -e "$f" ] || continue
  printf '%s\t%s lines\t%s jobs\n' \
    "$f" \
    "$(wc -l < "$f" | tr -d ' ')" \
    "$(yq -r '.jobs // {} | keys | length' "$f")"
done
```

Pull high-signal fields into a table:

```bash
find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort |
while read -r f; do
  f="$f" yq -r '
    [strenv(f),
     ((.on // "" | tostring) | split("\n") | join(" ")),
     ((.permissions // "" | tostring) | split("\n") | join(" ")),
     (.jobs // {} | keys | join(","))] | @tsv
  ' "$f"
done
```

## Org inventory, clone-free

Fast path through code search:

```bash
for ext in yml yaml; do
  gh api --paginate \
    "search/code?q=org:ORG+path:.github/workflows+extension:$ext" \
    --jq '.items[] | [.repository.full_name, .path, .html_url] | @tsv'
done
```

Be honest about the search API: it is capped, can miss generated or uncommon extensions, and is not a complete estate inventory for large orgs. Use it to start, not to prove absence.

Fallback that lists repos, then fetches workflow directory contents:

```bash
gh repo list ORG --limit 1000 --json nameWithOwner,isArchived \
  --jq '.[] | select(.isArchived == false) | .nameWithOwner' |
while read -r repo; do
  contents=$(gh api "repos/$repo/contents/.github/workflows" 2>/dev/null) || continue
  jq -r --arg repo "$repo" '
    .[]? | select(.name | test("\\.(ya?ml)$")) |
    [$repo, .name, .download_url] | @tsv
  ' <<<"$contents"
done
```

Fetch one workflow without cloning:

```bash
gh api repos/OWNER/REPO/contents/.github/workflows/ci.yml --jq '.content' | base64 -d
```

## Duplication detection for sprawl

Hash normalized job bodies. Keep the normalization boring: remove labels that legitimately vary, then compare actual job definitions.

```bash
find estate-workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -print |
while read -r f; do
  yq -o=json '.jobs // {}' "$f" |
  jq -c --arg file "$f" '
    to_entries[] |
    {
      file: $file,
      job: .key,
      hash: (.value
        | del(.name, .environment.name, .concurrency.group)
        | tostring
        | @base64)
    }
  '
done |
jq -r '[.hash, .file, .job] | @tsv' |
sort |
awk -F '\t' 'seen[$1]++ {print prev[$1] "\n" $0 "\n"} {prev[$1]=$0}'
```

If you cannot materialize files locally, fetch each workflow with `gh api`, write the contents under the current repo workspace, then run the same comparison. Do not use `/tmp`.

## Classifier heuristics

### A. The monolith

Signals:

- One workflow is obviously larger than the others.
- A workflow crosses the 500-line heuristic, especially if most jobs are serial.
- Job names mirror old stages: `checkout`, `build`, `unit`, `integration`, `package`, `deploy`, `promote`.
- Long linear `needs:` chain where jobs could run independently.
- Broad triggers with no path selection.
- Shell scripts perform native Actions tasks such as setup, cache restore, artifact upload, deployment auth, or release creation.

Commands:

```bash
wc -l .github/workflows/*.{yml,yaml} 2>/dev/null | sort -n
wc -l .github/workflows/*.{yml,yaml} 2>/dev/null | awk '$1 > 500'
rg -n 'needs:|Jenkins|jenkins|gitlab|azure-pipelines|circleci|stage|pipeline' .github/workflows
rg -n 'npm install|pip install|curl .*release|tar -czf|aws configure|az login' .github/workflows scripts
```

Read the `needs:` graph. The problem is artificial sequencing, not file length by itself.

### B. Ungoverned sprawl

Signals:

- Similar jobs across repos with different action versions.
- Every repo owns its own deploy workflow.
- Permissions, OIDC, environment names, and runner labels vary without policy.
- No central reusable workflows, or shared workflows are consumed from branches with no version contract.

Commands:

```bash
rg -n 'uses: .*/\.github/workflows/.*@' estate-workflows
rg -n 'uses: actions/(checkout|setup-node|setup-python|cache)@' estate-workflows | sort
rg -n '^\s*permissions:|^\s*environment:|runs-on:' estate-workflows
```

The finding is not "duplication exists." The finding is operational consequence: fixes, audit changes, and runner migrations require many coordinated PRs.

### C. Monorepo running everything

Signals:

- Many top-level services/packages but workflows trigger broadly.
- Full test/build/deploy matrices run on every `pull_request`.
- Required checks are skipped by path filters and block merges, or path filters were avoided because of that deadlock.
- Merge queue exists but workflows do not handle `merge_group`.

Commands:

```bash
find . -maxdepth 2 -type f \( -name package.json -o -name pom.xml -o -name pyproject.toml -o -name go.mod \) -print | sort
rg -n '^on:|pull_request|paths:|paths-ignore:|merge_group|fromJSON|matrix:' .github/workflows
```

Design around required checks before adding path filters. A skipped required check is not a successful check; that is an architecture constraint, not a linter warning.
