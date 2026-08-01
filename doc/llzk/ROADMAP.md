# Clean → LLZK roadmap

## Architecture

Compile a flattened Clean `FormalCircuit` to a small backend-local typed IR,
render deterministic textual LLZK, and validate it with LLZK 3.0:

```text
Clean FormalCircuit
  → fail-closed analysis and generated layout
  → backend-local LLZK IR
  → textual .llzk
  → llzk-opt
  → llzk-witgen interpreter and execution engine
```

The initial implementation lives under:

```text
Clean/Backend/LLZK/
  Basic.lean
  IR.lean
  Analyze.lean
  Expression.lean
  Witness.lean
  Circuit.lean
  Print.lean
  Command.lean
  Test/
```

## Stage-1 capability

Accept:

- prime-field `FormalCircuit`s;
- flattened field inputs, outputs, and witnesses;
- structured witness IR only;
- field variables, constants, addition, and multiplication;
- assertions;
- lookup tables resolved by an explicit export registry;
- the two justified Addition8 natural division/modulo forms.

Reject before rendering:

- native or interaction witness programs;
- unresolved tables;
- `dataGet` and `hintGet`;
- unrecognized natural arithmetic;
- any constructor not covered by the selected backend contract.

## Critical path

```text
S00 Bootstrap
 → S01 LLZK 3.0 tooling
 → S02 handwritten golden contract
 → R0 P0 review
 → S03 typed emitter IR and renderer
 → S04 assertion-only vertical slice
 → R1 frontend-foundation review
 → S05 Addition8 witness computation
 → S06 tables and full constraints
 → S07 command and conformance harness
 → R2 Stage-1 acceptance
 → S08 proof baseline
 → S09+ constructor-by-constructor expansion
```

After S02, a separate VeIR audit may consume the frozen fixture corpus. It may
not redefine the textual contract or add a direct dependency to Clean.

## Stage-1 completion

Stage 1 is complete when one documented Lean command emits
`Addition8FullCarry.llzk`, the pinned `llzk-opt` accepts and round-trips it, both
witgen backends match each other, and their witnesses match Clean across the
recorded corpus. Unsupported cases must fail with structured diagnostics.

