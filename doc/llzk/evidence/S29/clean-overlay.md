# S29 Clean overlay K

## Provenance and scope

- Upstream base U: `0e53b9f2d05f06defa2aa0a859f549b611583f10`.
- Clean overlay K: `3d086f32a71d17cbddfb46c0dea63cd36c8aa552`.
- K's only parent: U.
- Branch: `clean-to-llzk/s29-clean-xor-range`.
- Worktree: `/home/alh/LLZK/clean-xor-range-contract`.

`git diff --name-status U..K -- Clean/` returned exactly:

```text
M Clean/Gadgets/Xor/Xor32.lean
```

The diff is 5 insertions and 5 deletions. Each of the four witness limbs changes
from raw `x.val ^^^ y.val` to executable
`(x.val % 256) ^^^ (y.val % 256)`. Completeness adds only
`Nat.mod_eq_of_lt`, which consumes the existing per-limb `< 256` assumptions.
Assumptions, Spec, soundness, lookups, and all other Clean paths are unchanged.

## Builds on exact clean K

The worktree was clean at K for these commands:

```bash
lake build Clean.Gadgets.Xor.Xor32 Clean.Gadgets.BLAKE3.BLAKE3G
lake build --wfail Clean
lake build CleanTests
```

Results:

- targeted build: PASS, 1,756 jobs;
- `Clean`: PASS, 1,855 jobs with warnings treated as failures;
- `CleanTests`: PASS, 1,747 jobs;
- the ten warnings in `CleanTests` are the inherited `sorry`s in
  `Clean/Utils/Test/TestCircuitProofStart.lean`, unchanged by U..K.

The local build directory used an isolated project output and the already
materialized dependency packages; no network or external repository changed.

## Review

All three independent Phase K reviewers returned GO. The semantic reviewer
found no issue: all eight operand narrowings
are present, normalized-byte identity uses existing hypotheses, and no semantic
contract or trust premise changed. The red-control reviewer independently
returned GO after checking the clean worktree, direct ancestry, exact one-file
scope, eight `% 256` occurrences, absence of new `sorry`/`admit`/`axiom`/`unsafe`,
and build attribution. The process reviewer independently checked the one-commit
ancestry, full U..K delta, clean worktree, local build-output attribution, and a
conflict-free read-only merge prediction. Each recorded build command exited 0.
No Phase K finding remains open; the exact U/K identities and one-path overlay
scope remain mandatory inputs to Phase M.
