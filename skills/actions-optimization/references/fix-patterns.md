# Actions Optimization Fix Patterns

All examples are complete workflows so they can be checked with `actionlint -`. Replace package managers, paths, and runner labels with measured evidence from the target repo. Documentation entry points live in [`../../actions-workflow-toolkit/references/docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md).

## 1. ARM64 runner trial

Use when a Linux job has no architecture-specific blockers. Current runner labels, specs, and pricing must be fetched through [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).

Before:

```yaml
name: arm-before
on:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: npm
      - run: npm ci
      - run: npm test
```

After:

```yaml
name: arm-after
on:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-24.04-arm
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: npm
      - run: npm ci
      - run: npm test
```

Rollback trigger: native dependencies, Docker images, or toolchains do not publish ARM64 artifacts.

## 2. Package-manager cache, not `node_modules`

Cache behavior, branch scope, and eviction rules are in [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost). The practical rule: cache the package manager's content-addressed store, then install cleanly. If feature branches miss cache while the default branch hits, check branch scope before rewriting keys.

Before:

```yaml
name: cache-before
on:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/cache@v4
        with:
          path: node_modules
          key: node-modules-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
      - run: npm install
      - run: npm test
```

After with built-in cache input:

```yaml
name: cache-after
on:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: npm
          cache-dependency-path: package-lock.json
      - run: npm ci
      - run: npm test
```

After with raw cache for a custom store:

```yaml
name: pnpm-cache-after
on:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: pnpm/action-setup@v4
        with:
          version: 10
      - run: echo "STORE_PATH=$(pnpm store path --silent)" >> "$GITHUB_ENV"
      - uses: actions/cache@v4
        with:
          path: ${{ env.STORE_PATH }}
          key: pnpm-${{ runner.os }}-${{ hashFiles('**/pnpm-lock.yaml') }}
          restore-keys: |
            pnpm-${{ runner.os }}-
      - run: pnpm install --frozen-lockfile
      - run: pnpm test
```

## 3. Cancel superseded PR runs safely

Concurrency syntax and queue behavior are in [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost).

Before:

```yaml
name: concurrency-before
on:
  pull_request:
  push:
    branches:
      - main
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm test
```

After:

```yaml
name: concurrency-after
on:
  pull_request:
  push:
    branches:
      - main
concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm test
```

Why this shape: event type avoids canceling across `push` and `pull_request`; cancellation only applies to PR updates, not default-branch validation.

## 4. Path filters without required-check deadlock

Path syntax is in [`docs-map.md#syntax-and-semantics`](../../actions-workflow-toolkit/references/docs-map.md#syntax-and-semantics). If the check is required, a filtered-out workflow must still produce a successful required context through a companion workflow.

Primary workflow:

```yaml
name: required-ci
on:
  pull_request:
    paths:
      - "src/**"
      - "package-lock.json"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm test
```

Companion workflow with the same check name:

```yaml
name: required-ci
on:
  pull_request:
    paths-ignore:
      - "src/**"
      - "package-lock.json"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "No code changes; required check satisfied."
```

## 5. Dynamic monorepo matrix

Matrix behavior and documented limits are in [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost) and [`docs-map.md#limits`](../../actions-workflow-toolkit/references/docs-map.md#limits). Use dynamic matrices when Usage Metrics shows full monorepo builds on narrow changes.

Before:

```yaml
name: matrix-before
on:
  pull_request:
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: true
      matrix:
        package:
          - api
          - web
          - docs
    steps:
      - uses: actions/checkout@v5
      - run: npm --workspace ${{ matrix.package }} test
```

After:

```yaml
name: matrix-after
on:
  pull_request:
jobs:
  discover:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.changed.outputs.matrix }}
    steps:
      - uses: actions/checkout@v5
      - id: changed
        run: echo 'matrix={"package":["api","web"]}' >> "$GITHUB_OUTPUT"
  build:
    needs: discover
    runs-on: ubuntu-latest
    strategy:
      fail-fast: true
      max-parallel: 4
      matrix: ${{ fromJSON(needs.discover.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v5
      - run: npm --workspace ${{ matrix.package }} test
```

Replace the discovery step with the repo's actual change detector. Keep global integration jobs when package boundaries are porous.

## 6. Job graph consolidation for tiny jobs

Use only when `/jobs` timings show fixed overhead dominates. Do not collapse jobs that isolate permissions, environments, or real parallel branches.

Before:

```yaml
name: graph-before
on:
  pull_request:
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm ci
      - run: npm run lint
  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm ci
      - run: npm run typecheck
```

After:

```yaml
name: graph-after
on:
  pull_request:
jobs:
  static-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
        with:
          node-version: 24
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
```

## 7. Checkout cost in monorepos

Checkout behavior is under workflow syntax and checkout action docs reachable from [`docs-map.md`](../../actions-workflow-toolkit/references/docs-map.md). Keep checkout shallow unless the job needs history, use sparse checkout when the job only needs a slice of the repo, and scrutinize LFS/submodules because they add network and checkout time.

Before:

```yaml
name: checkout-before
on:
  pull_request:
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: npm --prefix docs ci
      - run: npm --prefix docs test
```

After:

```yaml
name: checkout-after
on:
  pull_request:
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          sparse-checkout: |
            docs
            package-lock.json
          sparse-checkout-cone-mode: true
      - run: npm --prefix docs ci
      - run: npm --prefix docs test
```

## 8. Docker build cache

Docker cache details live in Docker action docs; GitHub cache limits are linked from [`docs-map.md#performance-and-cost`](../../actions-workflow-toolkit/references/docs-map.md#performance-and-cost) and [`docs-map.md#limits`](../../actions-workflow-toolkit/references/docs-map.md#limits). Use a stable `scope` so unrelated images do not evict each other.

Before:

```yaml
name: docker-before
on:
  pull_request:
jobs:
  image:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: false
```

After:

```yaml
name: docker-after
on:
  pull_request:
jobs:
  image:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: false
          cache-from: type=gha,scope=${{ github.workflow }}-${{ github.ref_name }}
          cache-to: type=gha,mode=max,scope=${{ github.workflow }}-${{ github.ref_name }}
```

If GitHub cache pressure is the bottleneck, use a registry cache instead of fighting repository cache eviction.
