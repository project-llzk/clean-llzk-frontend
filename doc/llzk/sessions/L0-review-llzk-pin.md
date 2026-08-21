# L0 — Review or advance the LLZK toolchain pin

Status: preflight complete; execution is next after S25's evidence commit

Depends on: S25 landed with G0-G12 green

Base integration commit: S25's resulting commit

Branch: a new `clean-to-llzk/l0-llzk-pin` branch from the post-S25 tree

## Objective

Run the accepted LLZK tools and the exact current-main candidate against one
frozen post-S25 frontend tree, then make an explicit evidence-backed decision to
retain or advance the LLZK source/tool pin.

This is a toolchain compatibility session, not a capability increment. The
frontend, corpus, generated showcase, theorem statements, and expected counts
stay fixed. A changed result must be explained before any pin moves.

## Decision boundary

The accepted pin remains
`5db6f8f9baaa40787a1a40625796497445f2da36`. The candidate inventoried on
2026-08-21 is current `project-llzk/llzk-lib` `main`:
`25fb3740ea3465c9129a06289297bb4f0554b7a5`.

Neither “main moved” nor “the version string still says 3.0.0” decides between
them. Do not edit `PINS.md`, the CI flake reference, or accepted-version logic
until the side-by-side matrix and the decision entry are complete.

At execution time, query `main` again. If it moved, freeze the new candidate and
refresh this inventory before building; do not silently substitute a new SHA
for the one reviewed here.

## Preflight inventory

The candidate is 25 commits ahead and changes 193 files. The compare contains
31,750 additions and 26,973 deletions, but generated/renamed PCL fixtures
dominate that number; excluding `test/` and `unittests/`, implementation churn is
3,921 additions and 1,305 deletions.

Changed surfaces relevant to this frontend:

| Surface | Measured delta | Compatibility risk |
|---|---|---|
| Concrete dialect syntax | No Felt, Array, Struct, or Constrain operation-definition file changed; `Function/Ops.td` adds a call-classification helper | Low, but G3/G4 must prove it |
| Product/analysis pipeline | Flattening, POD-to-scalar, polymorphic specialization, product-control-flow naming, poly lowering, and redundant-operation passes changed | High for G10a |
| SMT lowering | Five SMT backend files changed; poly lowering gained non-Felt equality handling and failure-path work | Medium/high for G10b and its declared refusals |
| Witness generation | Ten `tools/llzk-witgen/` files changed; output-scope selection was fixed, witness selection grew an R1CS scope, and WTNS output was added | High for G5-G7 and JSON shape |
| Memory semantics | Redundant read/write elimination fixed dynamic-array alias invalidation and observed writes | High once S28 emits richer arrays; still exercise now |
| Field registry | No field-definition change appears in the compare | Low, but all six `Square_*` probes still run |
| Build/provenance | `BUILD_TESTING=OFF` CMake was repaired; no new release tag establishes a compatibility contract | Must build the exact SHA through Nix |

The witness-output patch is directly relevant even though the frontend already
asks for `--output-scope=full-witness`: the interpreter changed from always
collecting full-witness bindings to honoring the requested scope, and the
execution-engine entry pass now carries an `OutputScope` rather than a boolean.
The full-witness result should stay identical; G5-G7 are the evidence, not that
expectation.

The product-program command remains `--llzk-product-program`; its internal loop
fusion pass was renamed to product-control-flow fusion. This should be a CLI
no-op for the harness, while the surrounding transform churn makes G10a a real
compatibility test rather than ceremony.

Commit titles and the exact compare evidence are recorded in
`evidence/L0/preflight.md`.

## Must read

- `AGENTS.md`
- `doc/llzk/CURRENT.md`
- `doc/llzk/PINS.md`
- `doc/llzk/GATES.md`
- `doc/llzk/PUBLIC-READINESS.md`
- S25's decision and evidence, especially the `U64Expr.val` theorem change

## Allowed scope

- `doc/llzk/{CURRENT,PINS,DECISIONS,PUBLIC-READINESS}.md`
- `doc/llzk/evidence/L0/`
- `.github/workflows/ci.yml` only if the accepted pin changes
- `scripts/llzk/lib.sh` only if the candidate's self-reported version or CLI
  requires an explicit, reviewed compatibility change

No Lean frontend, corpus, golden, or example change belongs here. If the
candidate requires one, record the incompatibility and return it to a separately
scoped session rather than making L0's matrix compare different frontends.

## Execution procedure

1. Freeze and record the post-S25 frontend SHA. Confirm a clean worktree and
   claim it as `L0`.
2. Re-query LLZK `main`, record the candidate SHA, commit titles, and compare
   URL. Stop for inventory refresh if it differs from this packet.
3. Materialize both toolchains by exact flake reference with
   `nix build --no-link --max-jobs 0 --print-out-paths`. Record the two store
   paths as evidence, not portable configuration.
4. Capture `llzk-opt --version` and the relevant `--help` entries for verify
   round trip, product program, SMT lowering, witness backend, output scope, and
   output checking. A version string is identification evidence only when tied
   to the exact flake invocation.
5. Run `scripts/llzk/e2e.sh` with the accepted tools. This is the same-tree
   baseline and must be green before the candidate is interpreted.
6. Run the same command with the candidate tools. Do not change expected counts,
   fixtures, declared SMT reasons, or the frontend between runs.
7. Compare both PASS banners and capture any changed diagnostics. In particular:
   - all 12 modules and 2 renderer fixtures parse and round-trip;
   - all 14 enter the product-program pipeline;
   - both witness backends match all 33 Clean vectors;
   - all six field-registry probes remain green;
   - the 10-lowered/4-declared-out-of-scope SMT split either remains or is
     changed by a separately justified improvement;
   - every discriminator and 53 harness error paths still go red as intended;
   - `EXAMPLES.md` still regenerates byte-identically.
8. Run the documented theorem/axiom probes on the unchanged Lean tree. Tool
   compatibility does not justify a weaker theorem closure.
9. Write the decision before editing a pin.

## Decision rule

Advance only if the candidate:

- is reproducible from its exact SHA;
- passes the complete same-tree matrix without weakening a gate or expected
  count;
- has no unexplained artifact, JSON, diagnostic, or pipeline change; and
- provides enough relevant correctness/maintenance value to justify moving from
  the already reproducible accepted input.

If both pass, advancing is permitted but not automatic. The dynamic-array
aliasing, poly-lowering, failure-path, and output-scope fixes are relevant
benefits; the absence of a tagged release and the much larger transform surface
are real costs.

If the candidate fails, retain the accepted pin and record the smallest exact
incompatibility plus a re-review trigger. Retention after review is a valid L0
result; leaving the delta unexamined is not.

## Acceptance and pin update

For either decision:

- commit `evidence/L0/accepted.txt`, `candidate.txt`, `provenance.txt`, and the
  final comparison/decision summary;
- update `CURRENT.md` and `PUBLIC-READINESS.md` from “not started” to the actual
  result;
- record a decision entry naming both SHAs and why one is accepted.

If advancing, additionally update in one commit:

- the LLZK row and provisioning command in `PINS.md`;
- the exact flake reference in `.github/workflows/ci.yml`;
- any expected self-reported version in `scripts/llzk/lib.sh`;
- the live-delta note, which must not continue describing the old comparison.

Then run G0-G12 again on the committed new pin. The candidate run made before
the pin edit is compatibility evidence; the post-edit run proves the repository
actually enforces and reproduces the decision.

## Non-goals

- S25's Clean/Lean alignment.
- S26/S28 capability or corpus growth.
- Treating WTNS/R1CS export as a new frontend claim.
- Publishing, pushing, or changing GitHub settings.

## Handoff

- Changes made:
- Candidate SHA:
- Accepted SHA:
- Decision:
- Full matrix:
- Resulting commit:
- Exact next action: execute S26 only after the accepted tool pin is committed
  and green.
