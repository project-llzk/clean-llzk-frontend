# What this backend does not establish

Every gate and theorem in this project has a boundary. This file is the list of
them, written so that a reader can find the boundary without reverse-engineering
it from a docstring.

It exists because R5 found that the project's failure mode was never bad code —
it was **claims stated more strongly than the code supports**, and those claims
were spread across docstrings where no one could see them together. Five
reviewers found nine of them. A gap that is written down is a decision; a gap
that is only implicit is a surprise.

Ordered by how much a reader would be misled by not knowing.

## 1. Lookup table rows are asserted by the caller, not checked

`Config.tables` carries `ExportTable`s — names and rows. Nothing in the compiler
can check that those rows are the rows of the Clean `Table` the circuit looks
into, because `Clean.Circuit.Lookup` stores a `RawTable`, which has already
erased the `Table` and kept only a `Contains` predicate. This is D012.

The consequence, which R5a and R5c found independently: compiling
`Addition8FullCarry` with a 512-row `@Bytes` succeeds, and the emitted module
admits `w0 = 300` where Clean's `ByteTable.Contains` does not — a satisfying
assignment LLZK accepts and Clean rejects. Both halves of G9 green, `llzk-opt`
green.

`ConstraintSet.globals` does **not** close this. Both sides of that conjunct
derive from `cfg.tables`, so on the path `compile` takes it is a tautology. An
earlier docstring said otherwise; that is withdrawn, and
`Test/Constraints.lean` now pins the tautology as a fact rather than describing
a protection.

What exists instead: `ExportTable.Certifies`, a proof obligation tying an export
table's name, arity, and ordered rows to a Clean `RawTable`, discharged for
`Gadgets.ByteTable` and `Gadgets.Xor.ByteXorTable` and demanded by
`CertifiedConfig`. `Config`'s constructor is private and
`Config.unsafeWithTables` is the only other way in, confined by G12.

This entry used to be **two** gaps, and only one of them was upstream. S24
closed the first:

1. **The erasure — closed by S24.** `Config.ofCertified` took `CertifiedTable`s
   and returned a plain `Config`, dropping the `Table` and the certificate, so by
   the time `compile` ran there was no certificate to see: the obligation was
   demanded at one wrapper and discarded there, and what reached the compiler was
   a convention plus a grep. An earlier version of this entry said the obligation
   was "carried and visible", which is exactly the kind of claim R5 exists to
   catch, and it survived four commits here after being written. The five public
   entry points in `WitnessCheck.lean` — `verify`, `compileSourceVerified`,
   `compile`, `emit`, `emitSource` — now take a `CertifiedConfig F`, which holds
   `CertifiedTable`s (an earlier version of this entry counted "seven" by
   including the two theorems about them); `ofCertified` is retired and there is
   no public function from a `Config` to a `CertifiedConfig`.
   `Test/Constraints.lean` records what this means for `fatBytes`: not a
   `#guard`, because the point is that there is no term to write down.
2. **The tie to the circuit's own table — open, and upstream.** Even with the
   certificate carried,
   the caller picks *both* sides of `Certifies`, so it can certify a table the
   circuit does not look into. Closing that needs the `Table` to survive into
   `Lookup` instead of being erased to a `RawTable`, which *is* a change to
   Clean's core. R7 closed a *sub*-gap here that was this backend's own. Before
   S28, `Certifies` constrained values only, so a certificate could pair rows exported
   under one name with a Clean table named another, making `spec_of_compile`'s
   lookup hypothesis incomparable with what the module asserts (R7-12).
   `ExportTable.Certifies` now demands `exported.name = table.name` and matching
   arity as part of the same row certificate.
   The caller still picks both sides; what it can no longer do is have them
   speak about different globals.

S24 executed S23, which closed (1) and left (2) exactly where it is. The
remaining gap is the one that matters most for soundness: a caller can still
certify a table the circuit does not look into, and `Gadgets.ByteTable`'s
certificate is the reason to believe the corpus is not doing that, not a proof
that no caller could.

## 2. Nothing said the renderer was faithful — **closed by A5**

Before A5, `emit = renderResult (compile …)`: every semantic theorem stopped at
the `Module`, and `Module.render` was outside all of them.

For `@compute` this was covered empirically: G5–G7 execute the rendered text
through two independent LLZK backends and compare against Clean, so a renderer
bug there shows up as a differential failure. **For `@constrain` nothing
covered it.**

**R5e's counterexample for this was wrong, and R6 ran it.** It said a
`Stmt.render` that swapped `constrain.in`'s operands would pass G3 and G4. It
does not: the two operands have different types, so `llzk-opt` rejects the result
outright — `use of value '%v4' expects different type than prior uses` when only
the operands move, and `custom op 'constrain.in' invalid kind of Type specified`
when the type suffix moves with them. Both were checked against the pinned
binary on `Addition8FullCarry.llzk`.

The gap is real; its witness is different, and the correct one is sharper. Three
`Stmt` forms — `readMember`, `constrainEq` and `constrainIn` — are emitted **only
into `@constrain`**, so a bug in their rendering cannot show up in `@compute`
where the differential lives. R6 verified two, again on
`Addition8FullCarry.llzk`, against the pinned tools:

- rendering every `struct.readm %self[@w{k}]` as `@w0`. `llzk-opt` is happy (`@w0`
  exists and has the right type), it round-trips, `--llzk-product-program` admits
  it, and both witgen backends still match Clean on vector 0. The emitted
  constraint system is a different one.
- dropping every `constrain.eq` line. Same four greens — this is R2's Control 4,
  reached through the renderer rather than through the lowering, and G9 cannot
  see it because G9 compares `Module`s.

The closing condition was therefore a parser back from the protected text (a
second reader, with the usual question of what checks *it*) or a semantic account
of the concrete syntax, which is item 7. The entry names a hazard the toolchain
demonstrably does not catch, rather than one it does.

R7 measured how alone this leaves the emit-time comparison: a module whose
`@constrain` body is *empty*, one with a constraint deleted, and one demanding
`out0 == 8` where `@compute` writes 7 all pass G3, G4, G5, G6, G10a **and G10b's
SMT lowering** (`evidence/R7/probes.txt`) — the toolchain checks `@constrain`
for well-formedness, never for content, and the discriminator's LLZK probe only
establishes that a *missing* `@constrain` function is rejected (an empty one is
accepted). The same holds for field names: retyping a babybear module as
`bn254` passes every binary gate, exactly as `Analyze.checkField`'s docstring
warns. None of this contradicts a documented claim — G9 is a precondition of
emission and the artifacts are hash-pinned goldens — but it means constraint
content and field correctness each rest on a *single* Lean-side check with no
independent downstream confirmation, which is the strongest argument this file
has for the parser.

**A5 closes the internal renderer gap.** The 2026-08-22 audit found its first
implementation incomplete: it ignored `felt.const`, `felt.add`/`mul`,
`global.read`, member declarations, and constraint parameters. Changing a
constraint-side `felt.mul` to `felt.add`, or changing `@w0` from `{signal}` to
`{llzk.pub}`, passed the old readback, G3/G4, and both full-witness checks; the
latter mutation observably changed `--output-scope=public`.

`RenderCheck.parse` now reads every `global.def`, every `struct.member`, every
constraint parameter, and every `Stmt` constructor in `@constrain`. It compares
names, visibility, dimensions, row-major values, SSA indices, operations,
operands, and independently reconstructed types with a projection of the typed
IR. Unknown body statements fail closed. It also checks the function boundary,
so moving the same lines into `@compute` is not an agreement. `Module.render`
returns `Except`; no supported artifact path receives text unless this
comparison succeeds, and `EmitMain` reports a diagnostic rather than writing a
partial artifact.

`Module.render_constraintSurface` proves that every successfully returned text
parses to exactly the typed module's protected surface. `Test/Print.lean` makes
success non-vacuous on both renderer fixtures and makes the check go red for a
same-typed member substitution, dropped equality/lookup/row construction,
changed global shape or row ordering, malformed row construction, changed
constraint arithmetic/constant/table read/parameter, changed member visibility,
renamed `@constrain` function, and changed field type. Both witness backends now
also compare `--output-scope=public` against Clean for every corpus vector, so
the visibility contract is executed independently of A5. The full corpus passes
through the checked renderer before G3-G10 see it.

What this does **not** close is D017: the parser establishes what concrete text
the backend wrote, not that LLZK's implementation gives that text the semantics
Clean assumes. It is deliberately not a general LLZK parser either; the
`@compute` surface retains its two-backend differential evidence, while every
other rendered form remains covered by typed construction, goldens, and
`llzk-opt` well-formedness. A new `Stmt` constructor makes the typed projection
non-exhaustive at compile time, while an unknown rendered constraint statement
is rejected by the parser.

## 3. The chain from the emitted constraints to a gadget's `Spec` — **closed by A2**

It used to read: `eqs_iff_of_compileSource'` relates the emitted `constrain.eq`s
to `ConstraintsHoldFlat`, which is **not** `ConstraintsHold.Soundness`, so "the
emitted module's constraints hold ⇒ the gadget's `Spec` holds" is proved nowhere.
R5e called it the statement a user most likely assumes the project has.

`Soundness.spec_of_compile` is that statement, and
`Test/Soundness.add8_spec_of_compile` is it for `Addition8FullCarry`:

> take any assignment of the emitted component's cells — `env` for the circuit
> variables, `outs` for the `@out{j}` members D008 adds — that satisfies every
> polynomial the reader extracts from `@constrain`, **and every ordered
> polynomial row in `C.lookups`** (each evaluated row is `fromNat` of one row in
> every same-named nested table in `C.globals`); assume
> the gadget's own `Assumptions` of the input; then the gadget's own `Spec`
> holds of that input and the corresponding output.

R7-12 found that the lookup hypothesis was instead stated over the *source's*
lookups via the certificate. S28's post-completion review closed that interface
gap: `ConstraintSet.lookupRows_of_agree` uses G9's ordered-row/global agreement
and the certificate's name equality to turn `C.LookupRowsHold` into the
source-indexed premise of `ofSource_lookups_iff`. The compatibility theorem
`spec_of_compile_sourceRows` retains the old, honestly named interface for
callers that already have that premise. `spec_of_compile` now takes the module
reader's rows directly. It still carries the caller-supplied `resolve`
hypothesis — that every source lookup is into one of the configuration's
certified tables — which is item 1's second half surfacing in the statement,
proved at the instantiations by `add8_lookups_are_byteTable` and
`and8_lookups_are_byteXor`.

Four links, three of them Clean's own: the two conjuncts of
`constraintsHoldFlat_iff_forall_mem` (item 4, closed by A1 — this chain could not
be built before it), then `Circuit.constraintsHold_toFlat_iff`, then
`Circuit.can_replace_soundness`, then the gadget's `soundness` field.

`can_replace_soundness` needs `Operations.FullGuarantees`, which is
`∀ i ∈ ops.interactions, i.Guarantees env` — vacuous for anything this backend
accepts, because `Analyze.recognizeOperation` refuses `.interact` by name. That
is the one place Stage 1's narrowness pays rather than costs.

**What it is not.** It is the *soundness* direction only: nothing here says the
module has a satisfying assignment. It is stated over the `ConstraintSet` the
reader extracts (both equality and ordered-lookup halves) and the certificate,
so D017 (item 7) and the renderer (item 2) still stand between it and the
emitted text. And the hypotheses of the form "this compile run succeeded" are
checked rather than proved, because `recognize` on a real gadget does not reduce
in the kernel: two are `#guard`ed (`compile … isSome`, `recognize … isOk`) and
the third (`ofModule … = some C`) is entailed by the first — an earlier version
here counted "three `#guard`s", which is not what the file contains (R7-15).

## 4. The lookup half of `ConstraintsHoldFlat` — **closed by A1**

It used to read: `ofSource_eqs_iff` covers the *assertion* half only; for the
lookup half there is `byteTable_lookup_iff`, which is stated and proved — but
instantiated nowhere, with its `hdiag` hypothesis discharged at no call site.

Both halves of that are now false, and the entry is kept because what closed it
is the shape the rest of this file's items need.

- **The semantic theorem exists.** `Lookups.ofSource_lookups_iff` is the lookup
  counterpart of `ofSource_eqs_iff`: Clean's `Lookup.Contains` holds of every
  lookup in the source exactly when each queried value is one of the field
  elements the emitted `global.def const` holds — which is what
  `constrain.in %table, %value` asserts under D017. Together the two cover both
  conjuncts of `constraintsHoldFlat_iff_forall_mem`.
- **`hdiag` is discharged, from the compiler's own check.** Three new theorems
  make "the compiler ran a check" into a proposition: `diagnose_of_mem_registry`
  (a clean registry means each entry is clean), `registryOk_of_recognize` (a
  recognized circuit had a clean registry) and `size_eq_of_recognize` (D010 as a
  theorem — the configured prime is the circuit's, which is what makes a bound
  against `cfg.field.prime` a bound against `FiniteField.size F`).
  `canonical_of_recognize` composes them into exactly the hypothesis
  `certified_membership` needs.
- **Both are instantiated**, at `Gadgets.Addition8FullCarry` under `withBytes`
  and at three-column `And8` under `withBytesAndXor`, in `Test/Lookups.lean`.
  The concrete resolution theorems prove from each gadget's own operations that
  every lookup uses the certified table claimed for it.

What is *left* of this entry is one hypothesis and it is named: `recognize
withBytes.toConfig addSrc = .ok r`, "the compiler accepted this circuit".
`recognize` on a real gadget does not reduce in the kernel, so it is a `#guard`
rather than a `rfl`, and adding `native_decide` to close it would trade a
checked fact for a trusted one — see item 8.

Two small refactors were needed to make any of this provable, and they are worth
knowing about because they are the kind of thing that silently blocks a proof:
`recognize`'s registry check was a `match … with | #[] => … | problems => …`,
whose patterns overlap, so Lean generates no equation lemmas and `split` fails on
it; and its `for` loop hid the field check inside `forIn`. Both are now shapes a
proof can name, with identical behaviour and identical diagnostics.

## 5. No verified translator; the misleading `lower_spec` fragment was retired

R5a abstracted its statement over the lowering function and proved it, with no
`sorry` and clean axioms, of five alternatives: one throwing on every expression,
one ignoring `ty` and emitting `bn254`, one appending `constrain.eq %v, 0` for
every subexpression, one emitting junk `struct.writem`s, and one redefining an
allocated SSA index.

`readStmt` is the identity on six of the eight statement forms and `Stmt.dst?` is
`none` for three, so those are invisible to all three conjuncts; and the reading
claim sits under `out = .ok v`, so refusing everything satisfies it.

It also does not compose. R5a-4 gives three obstructions to lifting it through
the assembly loops: `readStmts` over a real `@constrain` body extracts no
constraints at all; every `env` entry in `constrainBody` is a `readMember` result
the reader ignores; and the emitted bounds do not imply the distinctness
`ofModule` requires. A whole-function preservation theorem needs the reader
restated first, not the current one lifted.

Nothing outside `IR.lean` used it. The 2026-08-22 audit removed the entire
`ExprAlgebra`/`Assign`/`readStmts`/`lower_spec` block rather than retain roughly
390 lines of proof code that supported no active correctness claim and imposed
a second statement vocabulary to maintain. `ConstraintSet.agree` and
`WitnessSet.agree` remain the checks that do the work at every compile.

The gap is therefore stated without the misleading partial result: this is a
translation-validating frontend, not a verified translator. A future
preservation theorem must model every emitted statement, connect to the active
module readers, and compose through whole-function assembly; it should not
revive the retired statement unchanged.

## 6. G9 compares no types — **closed by A4**

It used to read: neither `ConstraintSet.ofModule` nor `WitnessSet.ofModule` reads
a `Ty`, so a babybear circuit emitted entirely as `!felt.type<"bn254">` passes
both `agree` checks, and what catches it is `Analyze.checkField`'s registry
membership — a different mechanism in a different file, while G9's summary
reports both halves green. Found by R5e.

Both readers now take the expected `Ty` and check it everywhere they look:
every `felt.const`, `felt.add`/`mul`, `struct.readm`/`writem`, `constrain.eq`
and `constrain.in` operand type, every parameter and every `struct.member`;
`global.def` element types are checked by the *constraint* reader, which is the
only one that can see a global (`@compute` cannot reference them, so
`WitnessSet.ofModule` maps a `globalRead` to `none` — R7-15 corrected "both
readers" on this one point). `agree` passes `Ty.felt cfg.field.name`, so the
field the module is read in is the field the *configuration* names rather than
one the module asserts about itself.

Array types are checked **exactly**, against the global being read: element type
and every dimension, so `global.read @Bytes : !array.type<255 x …>` or a
multi-column row with the wrong suffix shape is a mismatch here rather than
something only `llzk-opt` notices.

`Test/Constraints.lean` pins that it can go red — R5e's own counterexample, both
readers, on `Multiply` and on `Addition8FullCarry` (which exercises the array
path). Reading either module as `bn254` or `mersenne31` gives `none`, which is a
stronger answer than a failed comparison because a `none` cannot be mistaken for
an agreement.

One thing this shook out: `Corpus.Entry` now carries its `FieldSpec`. A `#guard`
in `Test/WitnessCheck.lean` checked that the reader accepts every corpus module
against a hard-coded babybear, which was wrong for five of the six `Square_*`
entries the moment the reader started looking. "Does the reader accept this
module" is a question about a field.

## 7. D017 — the reading of LLZK — has no formal basis

Everything the emitter believes about what `felt.umod`, `felt.uintdiv`, the five
bitwise/shift operations, `constrain.eq`, and `constrain.in` *mean* is a reading
of LLZK's documentation and its tools' behaviour, not a theorem. There is no
formal semantics of LLZK in Lean; producing one is VeIR's project (D003).

The `@compute` half has real evidence: 51 vectors across two independent LLZK
backends (45 with a Clean circuit behind them, 6 on the `Square_*` registry
entries whose expected values are computed in Lean), plus S26's direct probes
of every exact bitwise/shift spelling and R5c's all-field confirmation of the
`umod`/`uintdiv` reading. **The `@constrain` half has none**, and cannot acquire
any from this repository: `llzk-witgen`'s own help text says it ignores
`constrain()`, so there is no executor for it in the pinned toolchain.

## 8. Small, named, and real

- **The wide-field `U64Expr.val` bridge — resolved by refusal, not removed.**
  D033 admits `.val` only when the field size is at most `2^64`, proves every
  recursively admitted result below the prime, and refuses bn254/grumpkin
  `.val` trees. `eval_lt_upperBound` and the extended `eval_ofWitgen` now make
  that policy executable. General wide-field u64 support would still require a
  source-visible range contract or limb decomposition.
- **The copy-canonicalisation premise — closed by A7.** `WitnessSet.ofSource` collapses a
  witness cell that is a bare variable into the variable it copies, which is
  forced — the emitted module does not distinguish them. `WExpr.eval_rename` and
  `WExpr.eval_congr` prove that renaming preserves meaning.
  `WitnessSet.CopyCanon.step_preserves` now proves the premise for one cell, and
  `run_preserves` proves it inductively for the whole witness-program list.
  `ofSource` uses that proved `run` directly. The theorem-closure probe is in
  `evidence/A7/`.
- **`native_decide`** is in the trusted base of every concrete claim this project
  makes, through ten declarations. R5e reports that five of the eight uses in
  Clean's `Clean/Utils/Primes.lean` are literal `Nat` comparisons `decide` would
  close — but that file is Clean core, which this branch keeps byte-identical to
  the pinned base, so removing them is an upstream change. **That premise is now
  a gate** (R6): `check-pins.sh` fails if `git diff` against the pinned base
  touches anything under `Clean/` other than `Clean/Backend/LLZK/`, `Clean.lean`
  and `Clean/Test.lean`. It was true and checked nowhere, while this entry and
  D012's follow-up both argued from it.
- **Goldens detect drift, not error.** G2's expected text is the emitter's own
  output, regenerated by a script when it changes. It pins that a diff is
  reviewed; it cannot tell that the text was right to begin with. G3, G4 and
  G5–G7 are what make it more than a snapshot.
- **G9 is per-module, not per-corpus.** It is a precondition of emission, so it
  holds for every circuit — but only for circuits. The six `Square_*` registry
  entries have no Clean source, so G9 does not apply to them at all, and
  `EmitMain` reports them as such rather than as passing.

## What is *not* on this list

Worth stating, because a gaps file with no floor reads as though nothing holds.
These were attacked directly across R2–R5 and held:

- the `Poly` normal form and every one of its evaluation homomorphisms;
- `WExpr.eval_lt_upperBound`, structural `WExpr.eval_ofWitgen`, and
  `WExpr.eval_bitsOf` under D033's checked bounds,
  `ofStatic_certifies`, `byteTable_certifies`, `byteXorTable_certifies`,
  `certified_membership`, `values_lt_prime_of_diagnose`;
- `CanonicalRepr`'s enforcement at every entry point, and that its two laws
  really do pin `val` for a prime field;
- the absence of any false accept in the constraint comparison: R5c could not
  construct two semantically different sources whose constraint sets collide, nor
  a mismatched (source, module) pair `agree` accepts;
- the witness differential, clean on eight hostile sources across both backends;
- that Clean's core is byte-identical to the pinned base — and since R6 that is a
  gate rather than an observation, which is the difference between the two halves
  of this file.

## What is *not established*, and is not a gap either

Two things R6 looked at and left alone, recorded so that a later reviewer does
not spend the same hour deciding they are fine:

- **`Builder.assemble` bounds operands, it does not own them.** It refuses a body
  referencing an index at or above what that body allocated (R4b-3's repair). A
  `Value` imported from another component whose index happens to be *low* passes,
  and silently aliases a local value. Nothing on the supported path can produce
  one — `Circuit.lean` builds a single component and never holds two — so this is
  a property of the type, not a reachable defect.
- **Neither G9 reader compares member *counts*.** `ConstraintSet.ofModule` takes
  `numWitnesses` from the `{signal}` members and `WitnessSet.ofModule` takes the
  cell count from the writes, so a module declaring more members than it writes
  would read consistently in both. `Circuit.members` derives both from
  `r.witnesses.size`, so again nothing on the supported path differs.
