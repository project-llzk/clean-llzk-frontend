# S28 — Multi-column lookup tables: retire D013

Status: implementation complete; clean checkpoint, G0-G12 acceptance, and
post-completion adversarial review pending
Depends on: S26 implementation and evidence tip
`91d43ffd0b4dcfd0841cc97f402b2d6006c58358`
Branch: `clean-to-llzk/s28-multicolumn-tables`
Worktree: `/home/alh/LLZK/clean-llzk-frontend`

## Objective

Retire D013 without weakening D012: preserve a lookup as one typed row, export
certified multi-column static tables, and emit the exact LLZK 3.0 row-membership
form. Demonstrate the increment end to end with `And8`, whose S26 witness
operation is already admitted and whose only measured remaining blocker is its
3-column lookup.

This session does **not** claim XOR support. S26/D033 correctly refuses the
current XOR witnesses because their byte bounds live in circuit assumptions and
constraints rather than in witness IR. S28 removes one XOR-family blocker; a
separate source-visible or proved range contract must remove the other.

## Why this session exists

R7-05 found that the earlier roadmap's “exactly two witness constructors”
headline contradicted its own diagnostic counts. Most refusals in the measured
bitwise family are lookups into `ByteXorTable`: 3-column, 65536-row tables that
D013 refuses. S26 removed the safe `land` witness refusal from `And8`, leaving
that table as its only blocker. It deliberately retained the `lxor` refusals in
`Xor32`, BLAKE3, and Keccak.

The table registry already retains `arity` and rows, but the current backend
flattens rows for rendering, stores only one recognized lookup expression, and
states `Certifies` over single values. Merely deleting the arity check would
therefore confuse row membership with membership in a flattened bag of field
elements and break the assurance story.

## Required reading before implementation

- `AGENTS.md`, `CURRENT.md`, `PINS.md`, and `GATES.md`, as required by the
  session template.
- `DECISIONS.md`: D012, D013, D017, D022, and D033.
- `GAPS.md`: sections 1, 7, and 8.
- `evidence/S26/coverage.md` and `evidence/S26/llzk-bitwise-ops.md`.
- `IR.lean`, `Print.lean`, `Table.lean`, `Certificate.lean`, `TableCert.lean`,
  `Analyze.lean`, `Circuit.lean`, `Constraints.lean`, `Lookups.lean`, and
  `Soundness.lean`, plus their tests.
- The pinned LLZK source and tests for `array.new` and multi-dimensional
  `constrain.in`; prose memory is not a syntax contract.

## Mandatory decision and probe before lowering code

Record the result as a new decision before changing the lowering.

1. **Pin the LLZK surface.** Against exact source
   `25fb3740ea3465c9129a06289297bb4f0554b7a5` and its Nix output, establish the
   concrete syntax and verifier requirements for a nested constant table,
   constructing a row with `array.new`, and passing that row to
   `constrain.in`. Preserve the accepted typed surface through render,
   `llzk-opt`, round trip, and product formation. Record that `llzk-witgen`
   ignores `@constrain`; tool acceptance is evidence for syntax, not lookup
   semantics (D017).
2. **Choose one row-preserving emitter and G9 model.** `ConstArray` must retain
   table shape and `RecognizedLookup` must retain every entry in order. The
   builder must make the row type and global element type equal by construction
   or fail with a named diagnostic. `ConstraintSet.lookups`, its source reader,
   its independent module reader, and its global comparison must likewise retain
   one ordered row per lookup and the nested rows of each global. Flattened
   scalar membership is forbidden on either side of G9.
3. **Generalize the certificate, do not weaken it.** Restate `Certifies`,
   canonicity, and `certified_membership` over rows of arbitrary supported
   arity. The decision must settle how `CertifiedTable` and `CertifiedConfig`
   carry certificates for different row types in one configuration; merely
   proving a generic theorem while leaving the public carrier fixed to
   `Table F field` is not a solution. Re-prove the chain from successful
   recognition to the certificate premise. D012's residual source-table
   identity gap remains named in `GAPS.md`; S28 may not hide it behind a
   stronger name.
4. **Measure the real table.** `ByteXorTable` contains 65536 rows and 196608
   field values. Measure registry construction, certificate elaboration,
   rendering, and the pinned LLZK stages before calling the representation
   viable. If the current `#guard` discipline does not scale, use a generic
   theorem derived from the static table definition; do not replace proof with
   trust.

## Allowed implementation surface

- `Clean/Backend/LLZK/` emitter, recognizer, certificate, constraint-reader,
  soundness, corpus, showcase, and test modules needed for this increment.
- Renderer fixtures and exact negative fixtures for each moved refusal.
- `scripts/llzk/` only for genuine new artifact counts or diagnostics.
- `doc/llzk/` decisions, gaps, roadmap, current state, gate descriptions,
  example inventory, this packet, and S28 evidence.

Clean core outside `Clean/Backend/LLZK/`, `Clean.lean`, and `Clean/Test.lean`
remains byte-identical. Any source-language range contract is a separate
Clean-side increment and review, not an incidental S28 edit.

## Deliverables

1. A decision recording the probed LLZK row syntax, typed row representation,
   certificate statement, and scale result.
2. A typed `array.new`/row IR surface and protected renderer readback, with
   positive fixtures reaching the pinned tools and mutations going red.
3. Row-preserving `ConstArray`, `ExportTable`, `RecognizedLookup`, and
   `ConstraintSet` paths with exact arity/type checks and stable diagnostics.
   G9 must compare one ordered row per lookup and nested global rows, not a
   common scalarization performed by both readers.
4. A public certificate carrier that can hold the existing single-column table
   and `ByteXorTable` together; generic row certification and the corresponding
   lookup/soundness lemmas; a concrete `ByteXorTable` certificate; and an
   `And8` instantiation of the lookup-to-`spec_of_compile` chain. No theorem may
   remain assurance-critical but instantiated nowhere, and no new axiom or
   weakened table-certificate requirement is allowed.
5. `And8` in the external-tool corpus with boundary vectors checked against
   Clean by both witness backends.
6. A re-measured coverage sweep. `And8` must compile; the XOR family must retain
   exactly its justified D033 witness refusals even when its table refusals
   disappear.
7. Scale evidence for the full 65536×3 table and exact G0–G12 evidence on a
   clean implementation commit.

## Negative obligations

At minimum, pin refusals for an arity mismatch, a row-width mismatch, a row
element of the wrong field type, an empty/invalid multi-column table where the
registry contract forbids it, and any malformed row construction accepted by a
shallower parser. Re-run the existing unresolved-table, duplicate-name,
out-of-field-value, and protected-renderer mutations. G9-specific mutations must
also make `agree` go red when one row is split into independent scalar
memberships, when two columns are exchanged, and when a global's values are
regrouped or transposed without changing the flattened scalar bag.

## Non-goals

- Adding or assuming the XOR byte-range contract.
- Promoting `Xor32`, BLAKE3, or Keccak to the corpus while D033 still refuses
  their witness expressions.
- Changing the S26 u64 width/bound or shift-count policy.
- Dynamic tables, source-table identity repair in Clean core, loops, control
  flow, or unrelated witness constructors.
- Pushing, opening external issues, or mutating the integration branch without
  explicit authorization.

## Boundary ownership and issue candidates

- **XOR range evidence:** open capability gap, owned upstream by Clean's source
  or constraint-analysis surface. Upstream issue #429 and PR #442 moved witness
  naturals to u64 but did not expose a bound certificate to downstream
  exporters. A focused upstream enhancement issue is warranted; none is opened
  by this bootstrap.
- **Shift counts:** accepted local refusal under D033, not an upstream bug.
  Clean masks u64 shift counts modulo 64 and LLZK shifts by the supplied felt
  representative. Counts at least 64 and unproved dynamic counts stay refused;
  a future masked-lowering feature may get its own local session if demanded.
- **Multi-column tables:** local frontend capability gap D013, owned by S28.

## Acceptance gates and evidence

The implementation commit must pass G0–G12 with the exact accepted pins. The
acceptance commands are:

```bash
LLZK_SESSION=S28 \
LLZK_OPT=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin/llzk-opt \
LLZK_WITGEN=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin/llzk-witgen \
bash scripts/llzk/e2e.sh

lake env lean doc/llzk/evidence/S28/probe.lean
```

In addition to the ordinary gate log, preserve:

- `evidence/S28/bootstrap.txt` — branch point, pins, ownership, and scope;
- `evidence/S28/pre-implementation-review.txt` — adversarial bootstrap-review
  findings, repairs, and targeted checks;
- `evidence/S28/llzk-multicolumn-ops.md` — primary-source syntax and direct
  pinned-tool probes;
- `evidence/S28/scale.md` — 65536×3 measurements;
- `evidence/S28/coverage.md` — exact before/after diagnostic decomposition;
- `evidence/S28/probe.lean` — theorem/axiom closure; and
- `evidence/S28/gates.txt` — final clean-commit G0–G12 run.

## Pre-implementation adversarial review

The 2026-08-21 review accepted the bootstrap provenance and technical premise,
but found four packet/control omissions before lowering began. This revision
closes them by making row shape part of both sides of G9, requiring a
heterogeneous public certificate carrier and a concrete `And8` soundness-chain
instantiation, adding the missing wide-field `.val` refusal fixture, and
synchronizing the required reading and milestone state. These are controls on
the forthcoming implementation; they make no LLZK syntax or representation
decision themselves.

## Bootstrap state

The branch was cut from final S26 evidence tip `91d43ffd`. The worktree is held
by session S28, the accepted Clean and LLZK pins pass their provenance check,
and the pinned LLZK tools pass the doctor check. No syntax decision, lowering,
certificate change, corpus change, build, compatibility gate, push, or external
issue creation occurred during bootstrap.

The mandatory LLZK syntax probe is preserved in
`evidence/S28/llzk-multicolumn-ops.md`, and D034 records the resulting
row/certificate design. No lowering code changed while making that decision.

## Implementation state

The interrupted implementation was recovered and completed on 2026-08-22.
`Ty.array` carries dimensions, `ConstArray` retains nested rows,
`RecognizedLookup` retains every column, and arity-three queries lower through
`array.new`. Both G9 readers compare ordered polynomial rows and nested globals;
their split-row, swapped-column, and regrouped-global controls are red.

`ExportTable.Certifies` now ranges over heterogeneous `RawTable` rows and ties
name, arity, and ordered canonical rows together. `byteXorTable_certifies`
covers the full table, `withBytesAndXor` holds arity-one and arity-three tables
together, and the lookup and `spec_of_compile` chains are instantiated at
`And8`. The corpus contains 15 artifacts and 51 vectors, of which `And8`
contributes six.

All changed backend test targets pass with `--wfail`. Direct scale measurements
are in `evidence/S28/scale.md`; the coverage delta is in
`evidence/S28/coverage.md`. The implementation was frozen as `03bf2f9b`; the
committed theorem probe and full pinned G0-G12 suite both passed on that clean
tree, as recorded in `evidence/S28/gates.txt`. The requested post-completion
adversarial review now runs against that frozen result.
