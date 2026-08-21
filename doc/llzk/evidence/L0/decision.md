# L0 LLZK pin decision

Date: 2026-08-21

## Decision

Advance the accepted LLZK source/tool pin from
`5db6f8f9baaa40787a1a40625796497445f2da36` to
`25fb3740ea3465c9129a06289297bb4f0554b7a5`.

## Same-tree result

Both exact Nix outputs ran against frontend commit `782160dd` with no
intervening frontend, corpus, fixture, example, expected-count, or theorem
change.

| Check | Previous pin | Candidate |
|---|---:|---:|
| G0-G12 | PASS | PASS |
| Corpus / vectors / backends | 12 / 33 / 2 | 12 / 33 / 2 |
| Renderer fixtures | 2 | 2 |
| Product-program admissions | 14 | 14 |
| SMT lowered / declared out of scope | 10 / 4 | 10 / 4 |
| Harness red paths | 53 | 53 |
| Field-registry probes | 6 | 6 |

The candidate preserved the full-witness JSON checks on both interpreter and
execution-engine backends. Its only relevant help-surface addition was the
expected WTNS output option. No unexplained artifact, diagnostic, or pipeline
change was observed.

The unchanged theorem probe in `probe.lean` also passed. The generic soundness,
lookup, registry, D026 witness, and renderer theorems depend only on `propext`,
`Classical.choice`, and `Quot.sound`; the copy-canonicalisation theorems use the
documented smaller subset; concrete babybear examples add only the two named
`native_decide` prime facts. No `sorryAx` appears.

## Why advance

The candidate is reproducible at an immutable SHA from the accepted public
cache and passes the whole unchanged compatibility matrix. Its 25-commit delta
contains correctness and maintenance fixes directly relevant to this frontend:
honouring witness output scope, dynamic-array alias invalidation and observed
writes, non-Felt poly equality lowering, error rather than assertion failure in
poly lowering, and a repaired `BUILD_TESTING=OFF` build.

The costs are real: no newer tag defines a release contract, the transform
surface is substantially larger, and the version banner remains 3.0.0. Exact
SHA pinning, cache provenance, the same-tree matrix, and the post-pin repository
run are the controls for those costs; the version string alone is not treated as
identity evidence.

`scripts/llzk/lib.sh` requires no edit because both exact revisions correctly
report the already expected LLZK version 3.0.0. WTNS/R1CS export remains outside
the frontend's claims.

## Post-pin gate

After the pin, CI flake reference, and active documents are committed, G0-G12
must pass once more with the repository-provisioned candidate. That result is
recorded in `post-pin.txt`; it is the acceptance evidence for the enacted pin.
