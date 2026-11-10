# CI guards for zharness consumers

`zharness install` writes no git hooks, so the secret scan and the commit-message check this repository runs locally (`scripts/install-git-hooks.sh`) do nothing in a consumer repository until that repository adds them. This guide is the CI template that closes the gap. It enforces the same two checks over a pull request's range, taken from the same source, so a local-hook bypass gains nothing.

| Check | What rejects | Source |
|---|---|---|
| Secret scan | an added line shaped like an AWS access key, a PEM private key or a URL with embedded credentials; a `.env`, `*.pem`, `*.key` or `*.p12` file. Reports `file:line` and the pattern name, never the value. | the `ZGUARD-CORE` block of `scripts/install-git-hooks.sh` |
| Commit message | a non-merge commit whose message has no `type(scope): description` line (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`, `revert`) | the commit-msg hook in the same file |

The scan runs over the net diff of the PR range and over each non-merge commit, so a secret added in one commit and deleted in the next still fails. Merge commits are skipped: a base sync carries the base's lines, not the PR's.

## How it works

`scripts/ci/pr-guards.sh <base> <head>` reads both guards out of the installer at runtime; it holds no guard logic of its own. In this repository the installer comes from the merge-base revision, so a PR cannot neuter its own guard. A consumer has no installer, so the template downloads `scripts/ci/pr-guards.sh` and `scripts/install-git-hooks.sh` from this repository at a pinned commit and points `ZHARNESS_GUARD_SRC` at the second. Because both files come from the pin rather than from the consumer's PR, the PR cannot rewrite them.

## Template

Save as `.github/workflows/zharness-guards.yml` in the consumer repository. Replace `MONOHARNESS_REF` with a full 40-character commit SHA of `tinhtute/monoharness` at or after the commit that added `scripts/ci/pr-guards.sh`; a branch or tag name moves, a SHA does not. Review the two files at that SHA before pinning it, and re-pin on purpose when you want newer guards.

```yaml
name: zharness-guards

on:
  pull_request:

permissions:
  contents: read

jobs:
  guards:
    runs-on: ubuntu-latest
    env:
      MONOHARNESS_REF: "<40-character commit SHA>"
    steps:
      # The guard walks a range, so the checkout needs full history.
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Fetch the pinned guard scripts
        run: |
          d="$RUNNER_TEMP/zharness-guards"
          mkdir -p "$d"
          raw="https://raw.githubusercontent.com/tinhtute/monoharness/$MONOHARNESS_REF"
          curl -fsSL -o "$d/pr-guards.sh" "$raw/scripts/ci/pr-guards.sh"
          curl -fsSL -o "$d/install-git-hooks.sh" "$raw/scripts/install-git-hooks.sh"

      - name: Secret scan and commit-msg check over the PR range
        env:
          ZHARNESS_GUARD_SRC: ${{ runner.temp }}/zharness-guards/install-git-hooks.sh
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: bash "$RUNNER_TEMP/zharness-guards/pr-guards.sh" "$BASE_SHA" "$HEAD_SHA"
```

Then mark the `guards` job as a required status check in the repository's branch protection. A check that is not required only reports.

## Run it locally

From a clone of the consumer repository, with the two files fetched as above:

```bash
ZHARNESS_GUARD_SRC=/path/to/install-git-hooks.sh bash /path/to/pr-guards.sh origin/main HEAD
```

Exit 0 is clean; exit 1 means a guard rejected the range or could not run (it fails closed, for example on a shallow checkout); exit 2 is a usage error.

## Verification

`scripts/ci/test-pr-guards.sh` runs the script against temp repositories (clean range, an AWS-shaped key, a key added then removed, a bad commit message, a stale base, a PR that guts its own installer, the consumer flow with `ZHARNESS_GUARD_SRC`) and checks that this template still names the files and variables the script requires.
