# S28 — Multi-column lookup tables: retire D013

Status: active, bootstrap only; syntax, representation, and certificate decisions
are still pending
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

- `DECISIONS.md`: D012, D013, D017, D022, and D033.
- `GAPS.md`: sections 1 and 7.
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
2. **Choose one row-preserving emitter model.** `ConstArray` must retain table
   shape and `RecognizedLookup` must retain every entry in order. The builder
   must make the row type and global element type equal by construction or fail
   with a named diagnostic. Flattened scalar membership is forbidden.
3. **Generalize the certificate, do not weaken it.** Restate `Certifies`,
   canonicity, and `certified_membership` over rows of arbitrary supported
   arity. Re-prove the chain from successful recognition to the certificate
   premise. D012's residual source-table identity gap remains named in
   `GAPS.md`; S28 may not hide it behind a stronger name.
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
3. Row-preserving `ConstArray`, `ExportTable`, and `RecognizedLookup` paths with
   exact arity/type checks and stable diagnostics.
4. Generic row certification and the corresponding lookup/soundness lemmas,
   with no new axioms and no weakened table-certificate requirement.
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
out-of-field-value, and protected-renderer mutations.

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

The implementation commit must pass G0–G12 with the exact accepted pins. In
addition to the ordinary gate log, preserve:

- `evidence/S28/bootstrap.txt` — branch point, pins, ownership, and scope;
- `evidence/S28/llzk-multicolumn-ops.md` — primary-source syntax and direct
  pinned-tool probes;
- `evidence/S28/scale.md` — 65536×3 measurements;
- `evidence/S28/coverage.md` — exact before/after diagnostic decomposition;
- `evidence/S28/probe.lean` — theorem/axiom closure; and
- `evidence/S28/gates.txt` — final clean-commit G0–G12 run.

## Bootstrap state

The branch was cut from final S26 evidence tip `91d43ffd`. The worktree is held
by session S28, the accepted Clean and LLZK pins pass their provenance check,
and the pinned LLZK tools pass the doctor check. No syntax decision, lowering,
certificate change, corpus change, build, compatibility gate, push, or external
issue creation occurred during bootstrap.

The first implementation action is the mandatory LLZK syntax probe and
row/certificate decision above.
