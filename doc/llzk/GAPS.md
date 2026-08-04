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
table to a Clean `Table`, discharged for `Gadgets.ByteTable` and demanded by
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
   catch, and it survived four commits here after being written. The seven public
   entry points now take a `CertifiedConfig F`, which holds `CertifiedTable`s;
   `ofCertified` is retired and there is no public function from a `Config` to a
   `CertifiedConfig`. `Test/Constraints.lean` records what this means for
   `fatBytes`: not a `#guard`, because the point is that there is no term to
   write down.
2. **The tie to the circuit's own table — open, and upstream.** Even with the
   certificate carried,
   the caller picks *both* sides of `Certifies`, so it can certify a table the
   circuit does not look into. Closing that needs the `Table` to survive into
   `Lookup` instead of being erased to a `RawTable`, which *is* a change to
   Clean's core.

S24 executed S23, which closed (1) and left (2) exactly where it is. The
remaining gap is the one that matters most for soundness: a caller can still
certify a table the circuit does not look into, and `Gadgets.ByteTable`'s
certificate is the reason to believe the corpus is not doing that, not a proof
that no caller could.

## 2. Nothing says the renderer is faithful

`emit = renderResult (compile …)`. Every theorem in this backend stops at the
`Module`. `Module.render` is outside all of them.

For `@compute` this is covered empirically: G5–G7 execute the rendered text
through two independent LLZK backends and compare against Clean, so a renderer
bug there shows up as a differential failure. **For `@constrain` nothing covers
it.**

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

So the closing conditions are unchanged: either a parser back to `Module` (a
second reader, with the usual question of what checks *it*) or a semantic account
of the concrete syntax, which is item 3. What changed is that the entry now names
a hazard the toolchain demonstrably does not catch, rather than one it does.

`Print.lean` proves the converse — equal modules render to equal strings. The
hazard is unequal modules rendering to equal text, or text LLZK reads differently
from how the `Module` meant it.

## 3. There is no chain from the emitted constraints to a gadget's `Spec`

`eqs_iff_of_compileSource'` relates the emitted `constrain.eq`s to
`ConstraintsHoldFlat`. That is **not** `ConstraintsHold.Soundness`, which is what
a `FormalCircuit`'s `soundness` field is stated over.

So "the emitted module's constraints hold ⇒ the gadget's `Spec` holds" is not
proved anywhere. Found by R5e. This is the statement a user most likely assumes
the project has, and it is now the largest gap that is *entirely inside this
repository*.

**A1 removed the first of its three prerequisites.** Bridging needed the lookup
half of `ConstraintsHoldFlat`, `Operations.FullGuarantees`, and the offset
correspondence between the flattened and unflattened operation lists. The lookup
half is item 4, and it is done: with `ofSource_eqs_iff` and
`Lookups.ofSource_lookups_iff`, both conjuncts of
`constraintsHoldFlat_iff_forall_mem` now have a semantic theorem on the emitted
side. What remains is the two structural steps from `ConstraintsHoldFlat` up to
`ConstraintsHold.Soundness` — and `Clean/Circuit/Subcircuit.lean`'s
`constraintsHoldFlat_iff` (`ConstraintsHoldFlat env ops.toFlat ↔
ops.ConstraintsHold env`) is where to start, because it is the same bridge stated
for Clean's own two representations.

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
- **Both are instantiated**, at `Gadgets.Addition8FullCarry` under `withBytes`,
  in `Test/Lookups.lean`. `add8_lookups_are_byteTable` proves from the gadget's
  own operations that every lookup it performs is into `Gadgets.ByteTable`.

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

## 5. `FieldExpr.lower_spec` is much weaker than its name

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

Nothing outside `IR.lean` uses it. `ConstraintSet.agree` still does the work at
every compile.

## 6. G9 compares no types

Neither `ConstraintSet.ofModule` nor `WitnessSet.ofModule` reads a `Ty`. A
babybear circuit emitted entirely as `!felt.type<"bn254">` passes both `agree`
checks. What catches it is `Analyze.checkField`'s registry membership, which is a
different mechanism in a different file — and G9's summary output, which reports
both halves green, obscures that the protection is elsewhere. Found by R5e.
`llzk-opt` also type-checks every operand (G3), so a module that reached a
verifier would not pass it; the gap is in what G9 itself licenses.

## 7. D017 — the reading of LLZK — has no formal basis

Everything the emitter believes about what `felt.umod`, `felt.uintdiv`,
`constrain.eq` and `constrain.in` *mean* is a reading of LLZK's documentation and
its tools' behaviour, not a theorem. There is no formal semantics of LLZK in
Lean; producing one is VeIR's project (D003).

The `@compute` half has real evidence: 30 vectors across two independent LLZK
backends, plus R5c's confirmation of the `umod`/`uintdiv` reading on all six
registry fields rather than only babybear. **The `@constrain` half has none**, and
cannot acquire any from this repository: `llzk-witgen`'s own help text says it
ignores `constrain()`, so there is no executor for it in the pinned toolchain.

## 8. Small, named, and real

- **The copy-canonicalisation premise.** `WitnessSet.ofSource` collapses a
  witness cell that is a bare variable into the variable it copies, which is
  forced — the emitted module does not distinguish them. `WExpr.eval_rename` and
  `WExpr.eval_congr` prove that renaming preserves meaning; the premise they are
  applied to, that `canon` only ever maps a variable to one the program defines
  it equal to, is checked by inspection of three lines rather than proved.
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
- `WExpr.eval_ofWitgen`, `ofStatic_certifies`, `byteTable_certifies`,
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
