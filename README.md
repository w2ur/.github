---
name: ".github"
tagline_fr: "La porte que les autres dépôts appellent."
tagline_en: "The gate every other repo calls."
---

# .github

Shared GitHub Actions for the portfolio. One reusable workflow —
`.github/workflows/pr-gate.yml` — called by a six-line file in each repo that
wants a pull-request gate.

Infrastructure, not a project: no hub tile, no deploy, nothing to visit.

## Use

In the calling repository, `.github/workflows/pr-gate.yml`:

```yaml
name: pr-gate
on:
  pull_request:
  push:
    branches: [main]
jobs:
  gate:
    uses: w2ur/.github/.github/workflows/pr-gate.yml@main
```

That is the whole integration. The workflow takes **no parameter describing the
stack** — it reads the tree, the same way `~/.claude/scripts/dev-scanner.sh`
does. Two optional inputs exist for cases the tree cannot express:

| Input | Default | For |
|---|---|---|
| `node-version` | `24` | Vercel's ceiling is 24 — do not raise past it. |
| `extra-env` | `""` | `KEY=VALUE` lines exported before every npm script. |

## Adding a caller

```bash
mkdir -p <repo>/.github/workflows
cp ~/Dev/.github/templates/caller.yml <repo>/.github/workflows/pr-gate.yml
```

`templates/caller.yml` is the copy-paste source and carries the two checks worth
making before opening the PR: absorb any existing `ci.yml` rather than running
both, and pass `extra-env` if the build reads the environment.

`~/.claude/scripts/gate-watch.sh` reports which repos have crossed into needing
one — repos discovered from `gh search prs`, never hand-listed. `/new-app`
scaffolds the caller into every new repo, so coverage does not depend on anyone
remembering.

## What it runs

Detected from the tree, never declared:

| Job | Runs when |
|---|---|
| `leaks` | always — gitleaks over the PR diff |
| `lint` | `package.json` has a `lint` script |
| `typecheck` | has a `typecheck` script, or `check` (Astro) |
| `test` | has a `test` script |
| `build` | has a `build` script |
| `ruff` | `pyproject.toml` has `[tool.ruff]` |
| `pytest` | `pyproject.toml` has `[tool.pytest…]` |

## The point of the thing

> Un contrôle qui n'a pas tourné ne doit jamais ressembler à un contrôle qui est
> passé.

GitHub Actions does not give you this. A job excluded by `if:` reports
`skipped`; a job dropped from a `needs:` list reports nothing at all; both read
as "not a failure". The obvious aggregate check is actively worse than none:

```console
$ echo '{}' | jq -e 'all(.[]; .result == "success")'
true          # exit 0 — a gate covering nothing reports success
```

`all` over an empty collection is vacuously true. So `gate` never asks *did
anything fail?* It asks *is every check that was supposed to run present and
green?*, against a list `detect` computes before any of them start — and it
refuses an empty list outright. `leaks` is unconditional, which is what
guarantees the list is never empty.

`gate` is the only job a branch protection rule should ever require. The others
are never required directly; requiring them individually reintroduces exactly
the hole `gate` closes, because a rule can only require a check it already knows
the name of.

## Verifying a change to the gate

`gate`'s logic is a shell script with no GitHub dependency, so it is tested as
one. `tests/gate-test.sh` drives it through twelve cases — nine that must be
red, three that must be green — including the two that a naive implementation
gets wrong:

```console
$ tests/gate-test.sh
--- cases that MUST be red (exit 1) ---
  PASS  exit=1  job removed from needs entirely
  PASS  exit=1  empty expectation — vacuous truth floor
  …
passed=12 failed=0
```

Run it before touching `gate`. A change that keeps all twelve green is safe; a
change that cannot turn any of them red has not been tested.

## Note on trust

Only GitHub-owned actions (`actions/*`) are referenced, by tag. There is no
third-party action in the trust path — gitleaks is fetched as a pinned binary
from its release page — which is why nothing here is pinned to a commit SHA.

---

Made with care by William — <https://william.revah.paris>
