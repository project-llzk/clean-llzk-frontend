# Contributing

This repository contains upstream Clean plus the experimental Clean to LLZK
frontend under `Clean/Backend/LLZK/`.

For frontend work, begin with [`doc/llzk/README.md`](doc/llzk/README.md), then
check [`doc/llzk/CURRENT.md`](doc/llzk/CURRENT.md) for the active base and exact
next action. Changes to Clean unrelated to the LLZK frontend normally belong in
the [upstream Clean repository](https://github.com/Verified-zkEVM/clean).

## Before opening a change

- Keep the analyzer fail-closed: every newly accepted source constructor needs a
  semantic justification, lowering, positive test, and negative boundary test.
- Do not change the pinned Clean or LLZK revision, expand the accepted language,
  or weaken a theorem hypothesis without recording the decision in
  `doc/llzk/DECISIONS.md`.
- Update `doc/llzk/GAPS.md` when a trust boundary changes. A green test does not
  silently close a documented gap.
- Preserve upstream attribution and avoid unrelated edits outside
  `Clean/Backend/LLZK/`; G0 checks the allowed Clean-core delta.

## Checks

For an ordinary Lean change:

```bash
lake build --wfail Clean
lake build CleanTests
```

For a frontend change, obtain the pinned tools from `doc/llzk/PINS.md`, claim
the worktree, and run the full conformance suite:

```bash
export LLZK_SESSION=my-session
export LLZK_OPT=/path/to/llzk-opt
export LLZK_WITGEN=/path/to/llzk-witgen
bash scripts/llzk/worktree-lock.sh claim "describe the change"
bash scripts/llzk/e2e.sh
```

The claim prevents concurrent sessions from rebuilding the same generated
artifacts and attributing evidence to the wrong tree. See
`doc/llzk/CONCURRENCY.md` if the worktree is already claimed.

The public corpus table in `doc/llzk/EXAMPLES.md` is generated from Lean. If a
corpus entry or its purpose changes, regenerate it explicitly:

```bash
lake env lean --run Clean/Backend/LLZK/ShowcaseMain.lean doc/llzk/EXAMPLES.md
```

The full conformance suite compares the generated and checked-in pages
byte-for-byte; do not repair a stale table by editing its counts manually.

## Pull-request evidence

A frontend pull request should state:

- the capability or assurance claim it changes;
- the exact Clean and LLZK pins used;
- positive, negative, and differential tests added or affected;
- whether emitted goldens changed, and why;
- the full gate result or the smallest named blocker;
- any decision-log or gap-register update.

Do not regenerate a golden merely because it differs. Inspect the rendered
change first: goldens detect drift, while the LLZK tools and Lean comparisons
provide the independent checks.
