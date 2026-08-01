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
  IR.lean          typed emitter model and its component builder
  Print.lean       the one place that knows LLZK's concrete syntax
  Expression.lean  FieldExpr, the closed accepted language, and its lowering
  Witness.lean     witness-program recognition; the capability boundary
  Table.lean       the lookup-table export registry
  Analyze.lean     Source, Recognized, recognize
  Circuit.lean     layout, compute/constrain lowering, compile, emit
  Poly.lean        canonical polynomials, with their evaluation theorems
  Constraints.lean gate G9: the emitted @constrain against Clean's constraints
  Examples.lean    worked example circuits
  RendererFixture.lean  modules exercising every IR constructor, for G2 and G3
  Differential.lean  Clean's own witness, in llzk-witgen's --check-output shape
  Corpus.lean      the conformance corpus: circuits plus input vectors
  EmitMain.lean    `lean --run` entry point that materializes the corpus
  Test/            goldens, rejection fixtures, and the G9 checks
```

`Command.lean` from the original sketch was not created: `#eval IO.print
(LLZK.emit …)` is the interactive form and `EmitMain.lean` is the artifact form,
so a macro would only have been sugar over one of them.

## Stage-1 capability

Implemented, golden-tested, and validated against the pinned LLZK 3.0 tools:
`llzk-opt` parses, verifies, round-trips and product-forms every emitted module;
both `llzk-witgen` backends agree with Clean's own witness interpreter across the
recorded input corpus; and no module leaves the backend without its `@constrain`
having been compared against the circuit's own constraint system (G9, D018).

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
- a witness cell that reads another cell of its own `.witness m` block, which
  Clean's `dynamicWitnesses` would evaluate to `0` (R2-03, D014);
- a table name that is not a legal MLIR symbol, collides with the component, is
  registered twice, is empty, or carries a value at or above the prime (D012);
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

R2 ran, reproduced the gates from repository files, and **returned Stage 1 for
repair** — 15 findings, four with working counterexamples, and one control that
mattered more than any of them: an `Addition8FullCarry` with an empty
`@constrain` passing every gate. The repair sessions follow:

```text
… → R2 → S08 → S09 → S10 → S11 → S12 → S13 → S14 → S15 → R3 → S16 → S17 → S18
```

R3 reviewed that repair and found three defects in it, all in S15's new code;
S16–S18 then closed the three gaps the repair had documented rather than fixed —
D012's lookup rows, G9's scope, and R2-05's missing field law. Both are recorded
in `review/R2-resolution.md`.

R0 and R1 were never run and are now moot: R2 covered their scope against a
larger surface.

A separate VeIR audit may consume the frozen fixture corpus. It may not redefine
the textual contract or add a direct dependency to Clean.

## Stage-1 completion

Stage 1 is complete when one documented Lean command emits
`Addition8FullCarry.llzk`, the pinned `llzk-opt` accepts and round-trips it, both
witgen backends match each other, their witnesses match Clean across the recorded
corpus, and the emitted constraints are Clean's. Unsupported cases must fail with
structured diagnostics.

The last of those was added to the definition by S14. R2 showed why: every other
criterion was met by a module whose `@constrain` was empty.

Status against that definition:

| Requirement | State |
|---|---|
| one command emits `Addition8FullCarry.llzk` | done — `lake env lean --run Clean/Backend/LLZK/EmitMain.lean <dir>` |
| unsupported cases fail with structured diagnostics | done — 19 negative fixtures pin exact messages, one per rejection path |
| `llzk-opt` accepts and round-trips | done — 11 modules and 2 renderer fixtures, G3 and G4 |
| every artifact is admissible to LLZK's analysis pipeline | done — G10a, all 13 |
| both witgen backends agree | done — 27 input vectors, G5 and G6 |
| witnesses match Clean on a corpus | done — G7, via `--check-output` against `FlatOperation.witgen` |
| the emitted constraints are Clean's | done — G9, and since S17 a precondition of emission, so for every circuit |

One command, `bash scripts/llzk/e2e.sh`, reproduces all of it.

### What is still not established

- **The witness side has no G9.** `@compute` is covered by G5–G7 differentially,
  on 27 vectors, and by nothing else. The class its preservation theorem needs
  now exists (`CanonicalRepr`, D019), so it is statable; it is not stated.
- **G9 validates each translation; it does not verify the translator** (D018,
  D020). A lowering bug surfaces as a refusal to compile rather than as a
  compile-time impossibility. D021 records what actually blocks the stronger
  statement — the emitter's privacy boundary, not the state monad — and the three
  ways out.
- **The reading of LLZK is an assumption** (D017): that `felt.add` is `+`,
  `constrain.eq` is equality, `constrain.in` is membership, and
  `!felt.type<"babybear">` is `ZMod 2013265921`. Nothing in Lean can settle it
  without a formal model of LLZK. Every emitted operation rests on it.
- **The compiler does not demand a table certificate.** D012's obligation is
  proved for every table in use (S16), and the build enforces it for the corpus,
  but `Config.tables` still takes bare `ExportTable`s.
- **The corpus is chosen, not exhaustive**, and nothing tests
  `Addition8FullCarry` outside its `Assumptions`.

