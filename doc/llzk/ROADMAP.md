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

## Public release-candidate milestone

Stage 1 proved the vertical slice. The next milestone is not simply "more
constructors": it is a repository that can move into the LLZK organization and
support its public claims under review. [`PUBLIC-READINESS.md`](PUBLIC-READINESS.md)
is the acceptance contract.

Its dependency order is:

```text
public documentation and hygiene
  → renderer round-trip assurance (A5, done)
  → S25: current upstream Clean and Lean
  → L0: review or advance the LLZK toolchain pin
  → S26: structural U64, bitwise operations, and conditionals
  → S28: multi-column lookup tables and certificates
  → end-to-end Xor32 plus one composed bitwise gadget
  → frozen-candidate adversarial review
```

This order joins the three goals that matter for publication. S25 removes the
stale Clean foundation; L0 decides against a measured 25-commit LLZK delta
rather than silently treating either the old pin or moving `main` as canonical;
A5 has already strengthened the one artifact boundary every pinned LLZK binary
accepts without checking semantic content. S26 plus S28 turns measured refusals
into impactful examples. The release candidate is reached only when those
examples are in the external-tool corpus, not when `LLZK.compile` merely returns
`some`.

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

## Measured coverage of Clean's gadget library

Stage 1's capability list above says what the *analyzer* accepts. It does not say
how much of Clean's actual library that is. The sweep is
`Clean/Backend/LLZK/Test/Coverage.lean` — every verdict below is a `#guard`
there, with the refusals counted *by kind*, so this table cannot drift without
moving a test (R7-06; the first version of this section was an interactive
session's output that nothing could re-run).

Measured by calling `LLZK.compile` on the real gadgets (so both halves of G9
ran; these are *not* corpus entries, so no `llzk-opt` or witgen has seen them):

| gadget | verdict |
|---|---|
| `Addition8FullCarry` | compiles |
| `ByteDecomposition` | compiles |
| `Addition32` | compiles |
| `Addition32Full` | compiles |
| `Rotation32` | compiles |
| `Rotation64` | compiles |
| `Not.Not64` | compiles |
| `Xor32` | refused — 1 × `lxor` + **4 × unregistered `ByteXorTable`** |
| `And.And8` | refused — 1 × `land` + **1 × unregistered table** |
| `BLAKE3.G` | refused — 4 × `lxor` + **16 × unregistered table** |
| `Keccak256.Theta` | refused — 50 × `lxor` + **400 × unregistered table** |
| `IsZeroField` | refused — `ite` (and the expression also needs `inv`) |
| `SHA256.SHA256Round` | n/a — needs `Fact (p > 2^33)`; but see below, field width is not its real blocker |

**The seven arithmetic rows compile**, subcircuits and lookups included:
`Addition32Full` and `Rotation64` are compositions several gadgets deep. That is
a real result and it was the surprise of the original sweep.

**The bitwise half is blocked by two features, not one** (R7-05 — the first
version of this section said "exactly two witness-IR constructors", and its own
diagnostic counts refute that: 80–89% of them are lookup refusals summarized
above as one word). Every byte-oriented bitwise gadget looks up `ByteXorTable`
or a sibling — **3-column, 65536-row tables**, and this backend is
single-column-only (D013). So:

- `land`/`lor`/`lxor` + `ite` (one witness-IR increment) removes the first
  column of refusals — and unlocks, by itself, only gadgets that use no lookup
  tables, roughly five.
- **Multi-column tables (D013's retirement)** removes the second, and is what
  actually stands between this backend and Xor32/And8/Keccak/BLAKE3 — together
  with certifying a 65536×3 table through `CertifiedConfig`, whose cost at that
  size nobody has measured.

Both move to the head of Stage 2, in that order; "subcircuits as named
components" stays behind them because it is a scaling concern, not a
capability one.

Denominators, stated so the table cannot imply them (R7-07): this sweep is 12
gadgets. `Clean/Gadgets/` has ~61 `FormalCircuit` tops; `Clean/Circomlib/`
(~35 circuits, Poseidon included), `Clean/Tables/`, `Clean/Examples/` and
`Clean/Air/` are unmeasured; and `GeneralFormalCircuit` (19), `FormalAssertion`
(8), `FormalTable` (3), `InductiveTable` (6) and `LookupCircuit` (1) tops are
not "refused" — `Compilable` has exactly one instance, `FormalCircuit`, so
they cannot reach `compile` at all. `SHA256Round`'s row above is also not a
field-width story: its witnesses use `let`-steps, `mapRange` outputs and `>>>`
(`Clean/Gadgets/SHA256/Add32.lean`), all refused, so it needs the witness-IR
loop increment *and* a `goldilocks`/`bn254` instantiation.

One smaller observation worth keeping: `Keccak256.Theta` produced 450
diagnostics rather than stopping at the first — D009's non-cascading property
working at a scale nothing had tested it at.

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
| unsupported cases fail with structured diagnostics | done — 29 negative fixtures pin exact messages. Not "one per rejection path": R5 found three reachable paths with none, and R7 found three more (R7-04); each round's were added |
| `llzk-opt` accepts and round-trips | done — 12 modules and 2 renderer fixtures, G3 and G4 |
| every artifact is admissible to LLZK's analysis pipeline | done — G10a, all 14 |
| both witgen backends agree | done — 33 input vectors, G5 and G6 |
| witnesses match Clean on a corpus | done — G7, via `--check-output` against `FlatOperation.witgen` |
| the emitted constraints are Clean's | done — G9, and since S17 a precondition of emission, so for every circuit |
| the emitted witnesses are Clean's | done — G9's witness half, S19/D020, likewise a precondition of emission |

One command, `bash scripts/llzk/e2e.sh`, reproduces all of it.

### What is still not established

**`doc/llzk/GAPS.md` is the register; this is the summary.** R6 found this
section had drifted into overstating four gaps that later sessions had closed,
which is the same failure mode in the opposite direction from the one R5 chased —
so read GAPS.md, and treat a disagreement between the two as a defect in this
file.

- **G9 validates each translation; it does not verify the translator** (D018,
  D020). A lowering bug surfaces as a refusal to compile rather than as a
  compile-time impossibility. D021 records what actually blocks the stronger
  statement — the emitter's privacy boundary, not the state monad — and the three
  ways out; `FieldExpr.lower_spec` is the fragment that exists, and GAPS.md item 5
  says how much smaller it is than its name.
- **The reading of LLZK is an assumption** (D017): that `felt.add` is `+`,
  `constrain.eq` is equality, `constrain.in` is membership, and
  `!felt.type<"babybear">` is `ZMod 2013265921`. Nothing in Lean can settle it
  without a formal model of LLZK. Every emitted operation rests on it.
- **Nothing ties a table certificate to the circuit's own table.** The compiler
  does now *demand* one — the public entry points take a `CertifiedConfig` (S24,
  D022) — but the caller picks both sides of `Certifies`, because `Table.toRaw`
  erased which `Table` a `RawTable` came from. GAPS.md item 1's second half; the
  fix is upstream in Clean's core.
- **The protected renderer surface now reads back (A5).** R6 and R7 showed why
  this mattered: the toolchain gates certify nothing about `@constrain` content.
  `RenderCheck.parse` is now the second line of defense, and
  `Module.render_constraintSurface` ties every successfully returned text to the
  typed module's `readMember`, `constrainEq`, and `constrainIn` sequence. This
  closes GAPS item 2 without closing D017's assumption about LLZK semantics.
- **The corpus is chosen, not exhaustive.** `Addition8FullCarry` is now tested
  outside its `Assumptions` (three of its nine vectors, S19).
