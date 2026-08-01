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
  Basic.lean       diagnostics, the LLZK field registry, Config
  IR.lean          typed emitter model and its SSA builder
  Print.lean       the one place that knows LLZK's concrete syntax
  Expression.lean  FieldExpr, the closed accepted language, and its lowering
  Witness.lean     witness-program recognition; the capability boundary
  Table.lean       the lookup-table export registry
  Analyze.lean     Source, Recognized, recognize, analyze
  Circuit.lean     layout, compute/constrain lowering, compile, emit
  Examples.lean    worked examples and the conformance corpus
  EmitMain.lean    `lean --run` entry point that materializes the corpus
  Test/            goldens for both accepted and rejected circuits
```

`Command.lean` from the original sketch was not created: `#eval IO.print
(LLZK.emit …)` is the interactive form and `EmitMain.lean` is the artifact form,
so a macro would only have been sugar over one of them.

## Stage-1 capability

Implemented and golden-tested on the Lean side; **not yet validated by any LLZK
tool** — see `CURRENT.md`.

Accept:

- prime-field `FormalCircuit`s;
- flattened field inputs, outputs, and witnesses;
- structured witness IR only;
- field variables, constants, addition, and multiplication;
- assertions;
- lookup tables resolved by an explicit export registry;
- the two justified Addition8 natural division/modulo forms, matched whole, with
  a literal divisor that is non-zero and below the prime (D011).

Reject before rendering:

- native or interaction witness programs;
- unresolved tables;
- `dataGet` and `hintGet`;
- unrecognized natural arithmetic;
- witness `let`-steps, `mapRange` and `append` outputs;
- lookup tables with arity other than 1 (D013);
- a configured field whose prime is not the circuit's (D010);
- any constructor not covered by the selected backend contract.

## Critical path

The planned order was:

```text
S00 → S01 → S02 → R0 → S03 → S04 → R1 → S05 → S06 → S07 → R2 → S08 → S09+
```

What actually happened: S01 stalled on a machine trust change outside a
session's authority, so S03–S07 were brought forward rather than idling. The
order run was

```text
S00 → S03 → S04 → S05 → S06 → S07 → [S01, S02, R0, R1, R2 outstanding]
```

The consequence is concentrated and known: the entire emitter's concrete syntax
was read from test fixtures in the pinned LLZK revision rather than confirmed by
the pinned binaries. S02 should therefore validate the *emitted* corpus first —
it is now a more useful subject than a handwritten fixture — and R0/R1/R2 should
review the emitter against the tools, not only against the fixtures.

After S02, a separate VeIR audit may consume the frozen fixture corpus. It may
not redefine the textual contract or add a direct dependency to Clean.

## Stage-1 completion

Stage 1 is complete when one documented Lean command emits
`Addition8FullCarry.llzk`, the pinned `llzk-opt` accepts and round-trips it, both
witgen backends match each other, and their witnesses match Clean across the
recorded corpus. Unsupported cases must fail with structured diagnostics.

Status against that definition:

| Requirement | State |
|---|---|
| one command emits `Addition8FullCarry.llzk` | done — `lake env lean --run Clean/Backend/LLZK/EmitMain.lean <dir>` |
| unsupported cases fail with structured diagnostics | done — eight negative fixtures pin exact messages |
| `llzk-opt` accepts and round-trips | **not run** — harness implemented, no pinned tool |
| both witgen backends agree | **not run**, and not implemented |
| witnesses match Clean on a corpus | **not run**, and not implemented |

