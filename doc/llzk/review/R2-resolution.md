# R2 — what was done about each finding

Companion to `R2-findings.md`. One row per finding and per control-set item, what
changed, and where the evidence is. Sessions S08–S15; evidence under
`doc/llzk/evidence/S08-S15/`.

R2's verdict was **returned for repair**. Every finding is discharged below.
Three are discharged by *recording* rather than by code, and they are marked as
such — a finding that a document overstates something is closed by the document
saying less, not by pretending the gap moved.

## Findings

| # | Severity | Resolution | Where |
|---|---|---|---|
| R2-01 | High | Closed **by construction**. The component name is no longer a parameter: it is always `@Main` (D015). A constant is a legal MLIR symbol by inspection, so there is nothing left to validate. `compile`/`emit` lost their `name` argument. | `IR.rootComponent`, D015 |
| R2-02 | High | `ExportTable.diagnose` takes the prime and rejects any row value at or above it, with a diagnostic that says why it is not a canonical representative. Negative fixture `unreducedTable`. | `Table.lean`, `Test/Circuit.lean` |
| R2-03 | Medium-high | `Analyze` threads the block's base offset and refuses any cell that reads a circuit variable its own `.witness m` block allocates — the discipline Clean calls `ComputableWitnesses`. A5 now holds for every accepted shape. Negative fixture `selfReadingBlock`. | `Witness.checkBlockLocal`, `Analyze.recognize` |
| R2-04 | Medium-high | `Builder.component` is the only constructor of a `StructDef` and takes **one** `ParamSpec` list for both functions, so the two parameter lists cannot disagree. `Builder.fresh` is private. `Module` holds one root, so `llzk.main` cannot dangle. The Print golden was rebuilt on that builder, is valid LLZK, and `e2e.sh` now feeds it and a second fixture to `llzk-opt`. D005 was rewritten to claim only what is true. | `IR.lean`, `RendererFixture.lean`, D005 |
| R2-05 | Medium | **Closed by S18**, having first been recorded by S14. The missing law is now a class, `LLZK.CanonicalRepr`, required by every recognizer and entry point — so a field whose `val` is not the ring representative is a type error, not silently wrong arithmetic. `val_natCast` shows the two laws pin `val` down. | D011, D019, `Field.lean` |
| R2-06 | Medium-high | `require_llzk_witgen_discriminates` runs before the loop: `llzk-witgen` must pass on a real corpus artifact's own expected witness and **fail** on the same witness with one signal perturbed. The vacuous-harness control now aborts at that step. | `scripts/llzk/lib.sh`, control 5 |
| R2-07 | Medium | 19 negative fixtures, one per rejection path, with the coverage table in the test file's docstring. One path listed in R2-07 is unreachable rather than untested — `Lookup.entry` is a `Vector _ table.arity` and `diagnoseRegistry` has already rejected every arity but 1 — and that is recorded where the branch is. | `Test/Circuit.lean` |
| R2-08 | Low-medium | Removed: `FeltBinOp.sub`/`div`, `Differential.publicOutputsJson`, `Circuit.diagnostics`, `Analyze.analyze`, `FieldSpec.ofPrime?`. The four unexercised registry fields are now exercised — see R2-13. | throughout; D009 records why the second entry point went |
| R2-09 | Low-medium | Every stale docstring corrected: the non-existent `lake exe llzk-emit`, `Test/Print.lean`'s two false claims, `EmitMain`'s "nothing partial is left", `Analyze`'s "the only capability gate", D006's `Builder.function`, and `Differential`'s input-encoding rationale. | throughout |
| R2-10 | Low-medium | D015 records the root-component name and D016 records both the `llzk.lang` spelling and why `llzk.fields` cannot be emitted. The emitter now matches ARCHITECTURE §5 on the first two; the third is a forced deviation and says so. | D015, D016 |
| R2-11 | Low | Counts corrected and re-derived: 19 negative fixtures, not eight; the duplicated `#guard`s are gone (one definition, in the test file). | `ROADMAP.md`, `CURRENT.md` |
| R2-12 | Medium | Two things. The artifacts are now admissible: with `@Main`, `--llzk-full-inlining --llzk-product-program` succeeds on all 13, and that is **gate G10a**, with no exceptions. And what the toolchain actually offers is written down, including the limit R2 did not reach: `llzk-smt-check` takes SMT-LIB, and no pass in the pinned `llzk-opt` emits the `smt.solver` op that `llzk-translate --smt-to-smtlib` requires, so no solver can be run. G10b lowers 9 of 13; R2 expected `Decompose` to be among them, but it fails on `felt.uintdiv`. | G10, `GATES.md` |
| R2-13 | Low | All six registry fields are now pinned behaviourally: one squaring component per field, checking `(p-1)^2 = 1` through both witgen backends. A `#guard` could not do this — `(p-1)^2 % p = 1` holds for any `p`, so the check is worth something only when LLZK does the arithmetic. | `Corpus.registryEntry` |
| R2-14 | Low | `inputsJson` emits decimal strings, like the output side. Exercised rather than argued: the `goldilocks`, `bn254` and `grumpkin` corpus entries feed `p-1` as an input. | `Differential.lean` |
| R2-15 | Low | Sessions record their resulting commit in their own Handoff, this session included. The R2 bootstrap's wrong `git rev-parse` instruction is corrected in its packet. `ROADMAP.md` no longer declares Stage 1 complete while listing the review that decides it as outstanding — it states the criteria, and R2's verdict and this repair are recorded against them. S06's missing packet is recorded as a deviation in `PROVENANCE.md` rather than back-dated. | `sessions/`, `ROADMAP.md`, `PROVENANCE.md` |

## Control set

| Control | Resolution |
|---|---|
| S1 — struct name never validated | Same as R2-01: moot by construction. |
| S2 — table name could collide with the struct name | `diagnoseRegistry` rejects a table named `Main`. Negative fixture `collidingTable`. The check lives with the rest of the naming policy, so the namespace is reasoned about in one place — the method gap R2 named. |
| S3 — the renderer golden has never been through `llzk-opt` | Same as R2-04: both fixtures go through it every run. |
| S4 — zero-of-everything edge cases untested | `passthrough` has no witness cells; the `Empty` renderer fixture has no members and no parameters; the six registry squares have no witness cells. A circuit with zero *inputs* is still untested, and is recorded here rather than fixed: `Source.ofFormalCircuit` instantiates at `size Input` variables, so it needs a `ProvableType` with `size = 0` to construct, which is Stage-2 surface. |
| S5 — an output that is an input, or a constant, untested | `passthrough` and `constOut` are corpus entries. D008 records that they are its own coverage. |
| S6 — `Ty` derives `Inhabited` | Removed, and D005 records the symmetry with `Value` that the control was really asking about. |

## The control R2 cared most about

Control 4 — an `Addition8FullCarry` with a completely empty `@constrain` passing
G3, G4, G5, G6 and G7 on all six vectors — is now caught, by G9. It still passes
G3, G4, G5, G6, G7 and G10, which is worth restating: those gates were never
going to catch it, and R2's contribution was demonstrating that rather than
asserting it.

`Test/Constraints.lean` pins the catch, along with four other perturbations, so
the gate's own falsifiability is checked on every build rather than by hand once.

## What the repair's own review found

A self-review is worth less than an independent one, and this one found three
things in its own work, all in S15's new code, all now fixed:

- `ConstraintSet.ofModule` had a vacuous guard. It checked
  `params.size = slots.size` where `slots.size` is defined as
  `1 + (params.size - 1)`, which is the same number. Replaced by a check that
  every parameter after `%self` has a felt type.
- The same reader accepted a `global.read` of a name the module does not define,
  leaving that to `llzk-opt`. It now checks against `Module.globals`.
- The falsifiability control set had no case for a lookup pointed at the *wrong
  table*. Added; the comparison is on the table name as well as the queried
  polynomial.

It also established something the design notes had under-claimed: the polynomial
normal form absorbs commutativity, associativity, distributivity and
cancellation, so the gate cannot report a spurious mismatch for two constraints
that are equal but differently written. `Poly.lean` said canonicity was "not
load-bearing", which is true of soundness and was hiding a property worth pinning.
It is pinned now, together with the two negative checks that stop those guards
being satisfied by a normal form that collapses everything.

None of this substitutes for R3.

## The three gaps this repair left, and what closed them

The first version of this document ended by listing three things the repair had
*not* done. Leaving them listed would have been the same failure R2 criticised —
recording a gap instead of closing it — so R3 reviewed the repair and S16–S18
closed all three. See `review/R3-findings.md`.

| Gap as originally left | Closed by |
|---|---|
| G9 compares two readers *on the corpus*, not for all circuits | **S17**: the comparison is a precondition of emission, so no module leaves the backend without it (D018). Not the `BuilderM` simulation argument, which is still the better artifact and still not done. |
| D012 — the lookup rows are trusted | **S16**: `ExportTable.Certifies` is the obligation; `ofStatic_certifies` and `byteTable_certifies` discharge it for every table this backend can be given. |
| R2-05 — the missing field law is recorded, not enforced | **S18**: `CanonicalRepr`, required by every entry point (D019). |
| It did not review itself | **R3**, which found three defects in S15's new code — a vacuous guard, an unchecked `global.read`, and a missing control — and fixed them. |

## What is still not established

Kept short and specific, because a long list of hedges is how the previous
version of this document hid three closable gaps:

- the witness side has no G9 — `@compute` rests on G5–G7 differentially;
- D017: that LLZK reads the emitted IR the way `ofModule` does;
- the compiler does not *demand* a table certificate, only proves one exists for
  the tables in use;
- R3 is not independent — it was written by the session that wrote the repair.
