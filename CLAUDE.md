# CLAUDE.md — .github

Shared GitHub Actions for the portfolio. See `README.md` for the calling
contract and the job table; this file is only the things that will bite you.

## The invariant is the product

Everything here exists to make one sentence true in CI:

> Un contrôle qui n'a pas tourné ne doit jamais ressembler à un contrôle qui est
> passé.

If a change makes `gate` simpler but loses that, the change is wrong. In
particular, **never** replace `gate`'s explicit loop with the shorter form
`jq -e 'all(.[]; .result == "success")'` — `all` over an empty collection
returns `true`, so dropping a job from `needs:` makes that expression exit 0
on zero coverage, the exact failure the job exists to catch (see the global
CLAUDE.md CI-gate rule for the measurement).

`gate` therefore iterates `EXPECTED` — the list `detect` computed up front — and
rejects an empty `EXPECTED` outright. `leaks` is unconditional so `EXPECTED` can
never be empty. Removing that unconditionality reopens the hole.

## Changing gate means running the tests

`tests/gate-test.sh` is a plain shell harness with no GitHub dependency
(`grep -c '^t ' tests/gate-test.sh` for the current case count; the red cases
are listed before the green ones in the same file). Run it before and after any edit to the
`gate` job, and keep the two scripts in sync — the `run:` block in
`.github/workflows/pr-gate.yml` and `tests/gate.sh` are the same logic
deliberately duplicated, because CI cannot source a file from the repo it is
gating.

If you add a case, make it fail first. A case that has never been red proves
nothing.

## Do not nest reusable workflows here

An earlier draft factored the four Node jobs into a `_node-step.yml` called with
`uses: ./.github/workflows/_node-step.yml`. That silently breaks every caller: a
relative `uses:` inside a reusable workflow resolves against the **calling**
repository, not this one. Hence four explicit jobs with duplicated setup steps.
The duplication is deliberate; leave it.

## Callers, and why so few

Caller selection and the branch-protection consequences are already covered in
the global CLAUDE.md — same rationale, same conclusion (private repos here get
an advisory `gate`, not an enforced one). Find the current callers with:

    grep -rl 'uses: w2ur/\.github/\.github/workflows/pr-gate\.yml' */.github/workflows/*.yml

The one thing worth stating here: `midas` deliberately does **not** call this
reusable workflow. It has documented `paths-ignore` reasoning, a conditional
`cancel-in-progress`, and a dual Python/Node suite that this generic workflow
would replace with something worse. It carries the same `gate` invariant
inline in its own `tests.yml` instead.

If enforcement ever becomes necessary on a private caller, the honest options
are: make the repo public, or have the repo's own merge automation read
`gate`'s conclusion via the API before merging.

## `extra-env` exists for one measured reason

`william-revah-paris` passes `CI=false`. Its `prebuild` runs
`scripts/build-inventory.mjs`, whose `shouldWriteInventory()` returns true when
`CI` is set — which on a runner means every PR build would crawl the GitHub API
across the whole portfolio (3 requests per repo — see `getReposToInventory()`
for the current repo count — unauthenticated, against a 60/hour limit) and then
discard the result. The script's own docblock documents
the escape hatch: *"A variable set to the string `false` or `0` reads as unset,
which is how CI systems disable one."* That is the supported path, not a hack.

## Repo layout note

`~/Dev/.github` is invisible to `dev-scanner.sh`, which excludes dot-directories
(`find … -not -name '.*'`). That is why this repo carries a README and a
CLAUDE.md rather than an entry in vigie's `NO_CLAUDE_MD_EXPECTED`: the exemption
list is keyed on repos the scanner sees, and this one it does not.
