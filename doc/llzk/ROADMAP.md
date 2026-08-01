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
  Examples.lean    worked example circuits
  Differential.lean  Clean's own witness, in llzk-witgen's --check-output shape
  Corpus.lean      the conformance corpus: circuits plus input vectors
  EmitMain.lean    `lean --run` entry point that materializes the corpus
  Test/            goldens for both accepted and rejected circuits
```

`Command.lean` from the original sketch was not created: `#eval IO.print
(LLZK.emit …)` is the interactive form and `EmitMain.lean` is the artifact form,
so a macro would only have been sugar over one of them.

## Stage-1 capability

Implemented, golden-tested, and validated against the pinned LLZK 3.0 tools:
`llzk-opt` parses, verifies and round-trips every emitted module, and both
`llzk-witgen` backends agree with Clean's own witness interpreter across the
recorded input corpus.

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
session's authority, so S03–S07 were brought forward rather than idling, and
S01/S02 ran last:

```text
S00 → S03 → S04 → S05 → S06 → S07 → S01 → S02 → [R0, R1, R2 outstanding]
```

The risk that created — five increments of syntax read from the pinned
revision's test fixtures rather than confirmed by its binaries — was retired by
S02 at zero cost: every gate passed on the first run and `Print.lean` needed no
change. S02 also dropped its planned handwritten fixture, which by then would
have been a second source of truth with no added assurance.

The review sessions R0/R1/R2 remain outstanding. R2 in particular should
reproduce everything from a clean checkout, since no session so far has.

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
| `llzk-opt` accepts and round-trips | done — 3 modules, G3 and G4 |
| both witgen backends agree | done — 16 input vectors, G5 and G6 |
| witnesses match Clean on a corpus | done — G7, via `--check-output` against `FlatOperation.witgen` |

**Stage 1 is complete.** One command, `bash scripts/llzk/e2e.sh`, reproduces all
of it.

The largest remaining assurance gap is that nothing checks the emitted
*constraints*: `llzk-witgen` executes `compute()` and ignores `constrain()`. That
is what S08 and the G9 proof track are for.

