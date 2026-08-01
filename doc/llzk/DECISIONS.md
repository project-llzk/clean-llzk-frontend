# Clean → LLZK decision log

## D001 — Host the first frontend in Clean

**Status:** accepted  
**Date:** 2026-07-31

Implement the first frontend as pure Lean under `Clean/Backend/LLZK/`. Emit a
small, deterministic textual LLZK subset and validate it with the pinned C++
LLZK 3.0 tools.

This avoids coupling Clean's Lean 4.30 toolchain to the project VeIR fork on
4.31-rc2 or upstream VeIR on 4.32.2.

## D002 — Use `alexanderlhicks/clean` as the project home

**Status:** accepted  
**Date:** 2026-07-31

The fork `alexanderlhicks/clean` owns the frontend implementation, fixtures,
conformance harness, decisions, pins, and cross-session handoffs.

Do not fork LLZK unless implementation uncovers a required LLZK dialect,
verifier, or witness-tool change.

## D003 — Keep VeIR non-blocking

**Status:** accepted  
**Date:** 2026-07-31

VeIR initially consumes the frozen `.llzk` fixture corpus as an independent
round-trip/checking track. A direct dependency is reconsidered only after
toolchains and required LLZK dialect coverage align.

## D004 — Fail closed on source semantics

**Status:** accepted  
**Date:** 2026-07-31

Clean's `NExpr` denotes unbounded natural arithmetic and is not generally field
arithmetic. Stage 1 recognizes only the explicitly justified Addition8
division/modulo shapes and rejects other natural expressions.

Lookup tables use an explicit backend registry because `RawTable` does not
retain concrete static rows.


## D005 — State exactly which malformed shapes the emitter IR rules out

**Status:** accepted, **amended by S11**
**Date:** 2026-08-01
**Enacted by:** S03, amended by S11

The backend does not build LLZK text by concatenating strings, and it does not
model MLIR generically. It has a small typed IR that admits only the Stage-1
subset. What that buys, stated as what a lowering *cannot* do:

- `IR.Value` has a private constructor and `Builder.fresh` is private, so the
  only values a body can name are ones a typed emitter returned to it or a
  parameter the builder handed it.
- `IR.Func.result : Option (Value × Ty)` is one field, so the rendered return
  type and the rendered `function.return` cannot disagree, and a body cannot be
  missing its terminator or carry two.
- `Builder.component` is the only constructor of a `StructDef`, and it takes a
  *single* `Array ParamSpec` and hands it to both functions. LLZK requires
  `@constrain`'s argument types, minus `%self`, to equal `@compute`'s.
- `IR.Module` holds one `StructDef` rather than a list, and the component is
  always named `rootComponent`, so `llzk.main` cannot dangle.
- Neither `Value` nor `Ty` derives `Inhabited`. `Value`'s was removed in S04 so
  no caller could conjure an SSA value; `Ty`'s was removed in S11 for symmetry —
  a `default : Ty` renders as `!felt.type<"">`, which `llzk-opt` rejects, so it
  could not corrupt a lowering silently, but leaving one instance and not the
  other invited the question R2 control S6 asked.

**What S11 amended, and why.** The original entry claimed "a struct that is not a
valid LLZK component cannot be built". That was false, and R2-04 produced the
counterexample from inside the repository: `Test/Print.lean`'s golden gave
`@compute` two parameters and `@constrain` one, which `llzk-opt` rejects, and the
golden passed G2 because G2 compares text to text. The third and fourth bullets
above are the repair; the golden is now also fed to `llzk-opt` by `e2e.sh`.

The general lesson is recorded rather than the specific fix: a decision entry
should say what a construction rules out, in terms a counterexample could
contradict, not that a whole class of error is impossible.

Consequence: the analyzer's job shrinks to *source*-side questions (is this
Clean construct in the subset?). It never has to re-check emitter
well-formedness. What is still checked outside the IR, because the IR has no
notion of a prime or of a symbol table, is the table registry — see D012.

## D006 — Derive `function.allow_non_native_field_ops` from the body

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S03

`Builder.assemble` inspects the statements actually emitted and adds the
attribute when any is non-native (`felt.uintdiv`, `felt.umod`). A caller cannot
forget it, and it is never added spuriously. (S04 moved this from
`Builder.function`, which no longer exists; the entry said otherwise until S14.)

`function.allow_constraint` and `function.allow_witness` are deliberately *not*
emitted: `llzk-opt` infers them from the function's role and prints them back, so
emitting them by hand would only risk a round-trip difference.

## D007 — One-per-line parameters, one-line array literals

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S03

Rendered function parameters go one per line so that adding or removing one is a
one-line diff in a golden fixture; gate G2 is only useful if a golden diff is
readable. Constant-array initializers stay on one line however long, because a
lookup table is a single logical value and wrapping would make the layout depend
on the row count.

## D008 — Outputs get their own public members

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S04

A Clean circuit output is an arbitrary `Expression`, not necessarily a witness
cell: it may be an input, a constant, or a sum. The backend therefore gives each
output field element its own `{llzk.pub}` member `@out{j}`, writes it in
`@compute`, and constrains it equal to the lowered expression in `@constrain`.

Alternative considered: mark "the witness cell an output points at" as
`{llzk.pub}`. Rejected because it needs a fallback for every output that is not
exactly a witness variable, and because it makes the public JSON key names depend
on the witness layout.

The extra `constrain.eq` per output does not change what the constraint system
proves — it defines a fresh cell as equal to an expression over existing ones.
What it buys is that `llzk-witgen --output-scope=public` reports exactly the
circuit's outputs under stable names, which is what gate G7 diffs against Clean.

That "does not change what the system proves" is now a theorem rather than an
argument: `ConstraintSet.ofSource_eqs_iff` (S15) separates the emitted
polynomials into Clean's assertions and the output definitions, and shows the
second hold exactly when each `@out{j}` equals its expression.

**Coverage, added by S13.** The shapes this decision exists for — an output that
is an input, and an output that is a constant — were argued for and never
emitted; the corpus contained only outputs that happened to be witness cells
(R2 control S5). `passthrough` and `constOut` are now corpus entries.

**Reopen when there is a downstream consumer.** The option D008 did not consider
is emitting outputs as `@compute`'s return value rather than as members. The
current shape doubles the public surface an analyser sees, and writes each member
in `@compute` *and* constrains it in `@constrain`, which is not a shape the rest
of the ecosystem produces. Nothing consumes these modules yet, so there is no
evidence to decide on; G10 is the first thing that will produce any.

## D009 — Recognize into a closed language, then lower totally

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S04

`Analyze` does not *validate* a Clean circuit and hand the original on. It
*translates* it into `Recognized`, built from `FieldExpr` — a closed language
containing only what the backend can emit. The lowering consumes `Recognized` and
is total apart from one genuine failure (an expression naming a circuit variable
nothing defines).

Consequences:

- There is exactly one place that decides what is in the subset. The lowering has
  no "unsupported" branch to keep in sync.
- There is one entry point, `compile`, and the diagnostics a caller sees are the
  ones the recognition pass produced. S11 removed the separate `analyze`/
  `diagnostics` pair: it was the "inspect the capability boundary without
  building a module" idea, it had no caller, and a second entry point is a second
  thing that can disagree about what is accepted (R2-08).
- Growing a capability is: one `FieldExpr` constructor, one case per recognizer,
  one case in `lower`, one positive and one negative fixture.
- The semantics theorems get a small closed language to talk about, instead of a
  predicate carved out of Clean's much larger witness IR. S15's gate G9 is what
  that bought.

Diagnostics are collected across all operations rather than stopping at the
first. Each operation is recognized independently, so a rejection cannot cascade.
The single piece of cross-operation state, added by S10, is the running witness
offset, and it advances by the `m` a `.witness m` operation *declares* rather than
by however many cells recognition managed to produce — so the non-cascading
property survives.

## D010 — The field name and its prime travel together

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S04

`Config.field` is a `FieldSpec` (name plus prime) drawn from `FieldSpec.registry`,
not a bare string, and `Analyze` rejects a circuit whose `FiniteField.size` is not
that prime. A wrong field choice is therefore a diagnostic rather than arithmetic
silently performed in the wrong field.

The registry is transcribed from `lib/Util/Field.cpp`, `Field::initKnownFields`,
at the pinned LLZK revision. Adding a field means adding it there, with its
prime — not passing a new string.

## D011 — Match the natural division/modulo shapes whole, with a literal divisor

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S05

`Witgen.NExpr` denotes unbounded `ℕ`. Lowering natural arithmetic to `felt.*`
piecewise is therefore wrong in general, because field reduction changes
intermediate values. The backend recognizes exactly two *whole* shapes:

```
ofNat (mod (val x) (const c))  ->  felt.umod    [x], felt.const c
ofNat (div (val x) (const c))  ->  felt.uintdiv [x], felt.const c
```

Matching the whole shape rather than `val`, `mod` and `ofNat` separately is what
makes this sound: no natural value escapes the pattern, so there is no
intermediate that could have exceeded the field.

The divisor is a `Nat` literal in `FieldExpr`, not a nested expression, so two
side conditions can be checked at recognition time:

- `c ≠ 0`. Lean's `Nat` division and modulo by zero are total (both `0`); LLZK's
  are not. Accepting this would be a silent semantic difference.
- `c < p`. `felt.const c` denotes `c mod p`, so a divisor at or above the prime
  would become a different number.

Given those, the lowering is faithful for the prime fields in
`FieldSpec.registry`: `FiniteField.val x` is the canonical representative in
`[0, p)`, which is exactly the operand interpretation LLZK's `umod`/`uintdiv`
use, and the result re-enters the field through `FiniteField.fromNat`, whose
`val_fromNat` law applies because `val x % c` and `val x / c` are both at most
`val x`, hence below the field size.

**One side condition of that argument is not checked, and cannot be** (R2-05,
recorded by S14). `FiniteField` abstracts over prime *and* binary fields, and its
laws — `val_lt`, `val_injective`, `val_fromNat`, `val_zero`, `val_one` — do not
say that `val` is the *ring* representative, i.e. that
`val (a + b) = (val a + val b) % size`. `Analyze.checkField` pins
`FiniteField.size F` only, and size `p` forces `F ≅ 𝔽_p` without forcing this
particular `val` to be that isomorphism. The same assumption underlies
`FieldExpr.ofExpression`'s `.const c ↦ felt.const (val c)`. Clean's instance for
`F p = ZMod p` uses `ZMod.val` and satisfies it, and the corpus confirms it
behaviourally, but G7 cannot detect a violation because `Differential.witness`
goes through the same `val`/`fromNat`.

**Closed by S18.** The class is `LLZK.CanonicalRepr`, and every recognizer and
entry point requires it, so the side condition is a hypothesis rather than a
hope. See D019. The constraint side never needed it — its only `val`/`fromNat`
dependence is on constants, discharged by `LLZK.fromNat_val` — which is why S15
could prove that side first; the witness side now has a class it can be stated
over.

This argument is otherwise prose, not a proof. Turning it into one is a P5
obligation, and it is the reason `FieldExpr` is a small closed language (D009):
there is something tractable to state it about.

Every other `NExpr` shape stays rejected. The general treatment — `NExpr.val` to
`cast.toindex`, natural arithmetic on `index`, `FExpr.ofNat` to `cast.tofelt` —
needs an index bounds policy and LLZK interpreter support that do not exist yet,
and is deliberately not an implicit backlog item.

## D012 — Table rows are trusted registry input, for now

**Status:** accepted, with a recorded follow-up
**Date:** 2026-08-01
**Enacted by:** S06

`Table.toRaw` discards a `StaticTable`'s `length` and `row`, so concrete rows
cannot be recovered by walking a circuit. `Config.tables` supplies them.

The backend checks what it can — the name resolves, the name is a legal MLIR
symbol, the name does not collide with the component, the arity matches the
circuit's lookup, rows all have that width, every value is below the prime, the
table is non-empty, names are unique — and refuses any lookup it cannot resolve.
It cannot check that the supplied rows are *the table's* rows, because
`RawTable.Contains` is a `Prop`, not something the compiler can evaluate. That is
a genuine trust assumption and is stated on `ExportTable`.

**Two of those checks were missing until S08**, and the gap was wider than this
entry admitted. `ExportTable.diagnose` did not check that row values are below
the prime (R2-02), so a registry entry of values `≥ p` was accepted, emitted
verbatim, and silently reduced by LLZK into a *different* set of rows. And no
check compared a table name against the component name (R2 control S2), which
produces a module `llzk-opt` rejects outright. Neither is D012's assumption:
both are things the backend can check and now does. The entry previously read as
though the row contents were uniformly untrusted, which made the missing checks
easy to mistake for the recorded gap.

**The trust assumption is discharged, by S16.** It was exactly one sentence —
*the rows supplied in `Config.tables` are the rows of the Clean table of that
name* — and one sentence is something you can write down as a `Prop` and prove.
`ExportTable.Certifies` in `Clean/Backend/LLZK/TableCert.lean` is that `Prop`,
and two theorems discharge it for every table this backend can be given:

- `ofStatic_certifies` — for *any* single-column `StaticTable`. `ofStatic`
  computes the rows from the table's own `row` function, so the only content is
  that `FiniteField.val` loses nothing, which is `val_injective`.
- `byteTable_certifies` — for `Gadgets.ByteTable`, the case this entry's
  follow-up said was open because it inlines its `StaticTable` and naming that
  breaks unrelated proofs. It does not need naming: `StaticTable.toTable` defines
  `Contains` from the `row` function alone, and `contains_iff` already relates
  that to `x.val < 256`. `Examples.byteTable_certified` closes the loop by `rfl`.

`certified_membership` is the payoff, and it is where the range check S08 added
does its work: for a certified table with canonical values, Clean's `Contains`
holds of `x` exactly when `x` is one of the field elements the emitted array
holds — which is what the emitted `constrain.in` asserts.

**The certificate is carried, not enforced — and an earlier version of this
entry said otherwise.** `Config.ofCertified` takes `CertifiedTable`s, and
`Examples.withBytes` uses it, so the corpus's only lookup table has its proof
next to its rows and changing the rows breaks the build. But R4a-2 broke the
"cannot be called without a proof" reading: the caller chooses *both* the export
table and the Clean table, and nothing ties the latter to the table the circuit's
`.lookup` names — that is a `RawTable`, resolved by name, and `Table.toRaw` has
erased which `Table` it came from. `selfTable e` with
`Contains _ x := val x ∈ e.values` certifies any rows at all, and the reviewer
compiled `Addition8FullCarry` with a one-row `@Bytes`.

So the residual is precise: the obligation is stated, and proved for every table
in use; the compiler cannot demand it. Closing that needs the `Table` to survive
into `Lookup`, which is a change to Clean's core rather than to this backend.

**And the bridge is now composed, not just available.** `certified_membership`
was proved and instantiated nowhere, with its canonicity hypothesis left to the
caller (R4a-6). `ExportTable.values_lt_prime_of_diagnose` discharges that
hypothesis from the check the compiler already runs — the one S08 added for
R2-02 — and `byteTable_lookup_iff` composes the two:

> `Gadgets.ByteTable.Contains t x  ↔  ∃ n ∈ @Bytes's values, fromNat n = x`

The left-hand side is Clean's lookup constraint; the right-hand side is what the
emitted `constrain.in %Bytes, %x` asserts. Everything between them is a theorem.

So what is left is not "the rows are trusted". It is D017's reading of
`constrain.in` as membership, which is a statement about LLZK, and the same
assumption every other emitted operation carries. The follow-up about naming
`ByteTable`'s `StaticTable` is no longer blocking anything; it would be a
tidiness change.

`ExportTable.ofStatic` is the mitigation: where a `StaticTable` is still in
scope, the rows are computed from its own `row` function and cannot disagree
with it.

**Follow-up, not done here.** `Gadgets.ByteTable` inlines its `StaticTable` into
`Table.fromStatic`, so the byte rows must be written out by hand rather than
derived. Naming that `StaticTable` was attempted during S06 and reverted: it
breaks every proof that unfolds `ByteTable` with `simp` — `Addition8FullCarry`,
`U32`, `U64` — because unfolding then stops at the named constant. Making those
proofs unfold both is a change to shared Clean gadget proofs, which belongs to a
Clean-side session with its own review, not to a backend increment.

## D013 — Single-column tables only, for now

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S06

A wider table needs an `array.new` query and a multi-dimensional `constrain.in`,
neither of which the emitter IR has. Rather than guess at that encoding, arity
other than 1 is refused with a diagnostic that says what it would take. Clean's
`ByteTable` — the Stage-1 target — is single-column.

## D014 — Differential testing compares against Clean's proved witness semantics

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S02

`Differential.witness` runs `FlatOperation.witgen`, Clean's array-backed
reference interpreter, which `witgen_eq_dynamicWitnesses` proves computes the
same witnesses as `FlatOperation.dynamicWitnesses`. The comparison is therefore
against a proved-equal pair of Clean definitions, not a reimplementation written
for the harness.

**The reference is `dynamicWitnesses`, not `localWitnesses`** (R2's objection to
this entry's original wording, "Clean's proved witness semantics"). The two come
apart on circuits whose `.witness m` block reads a cell the same block allocates:
`dynamicWitnesses` evaluates the whole block against the environment *before* it,
so such a read is `0`, while a straightforward `@compute` lowering reads the
computed value. Clean names the discipline that rules this out
`Operations.ComputableWitnesses`, and S10 made `Analyze` enforce it, so the class
of circuit on which the two definitions disagree is now rejected rather than
mis-emitted. See R2-03.

The comparison itself is `llzk-witgen --output-scope=full-witness
--check-output`, so a disagreement is a non-zero exit rather than two JSON dumps
for a reader to diff. G7 is carried inside G5 and G6 rather than being a separate
run.

The JSON keys come from `Circuit.lean`'s layout functions, shared with the
emitter. That is deliberate — it makes drift between the expected keys and the
emitted members impossible — and it has a known consequence: a bug *in the naming
scheme itself* is invisible to G7, because both sides would move together. G3/G4
and the goldens cover naming; G7 covers values.

**What G5–G7 do not establish.** `llzk-witgen` executes `compute()` and ignores
`constrain()`. Agreement means the two witness generators agree. G9 (D017) is
what checks the constraints; G5–G7 say nothing about them, and R2's Control 4
made that concrete by showing an `Addition8FullCarry` with an empty `@constrain`
passing all of G3–G7 on every vector.

## D015 — The root component is `@Main`

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S12

Every emitted module's component is named `Main`, fixed in `IR.rootComponent`
rather than derived from the circuit. The circuit's own name survives as the
artifact's file name.

Two independent reasons:

- `ARCHITECTURE.md` §5, the accepted design baseline, specifies
  `struct.def @Main`. Naming the component after the circuit was a deviation from
  it with no decision entry (R2-10).
- `llzk-opt --llzk-product-program` looks up a root struct named literally
  `Main` and **ignores `llzk.main`**. It is the entry point to
  `--llzk-to-smt-no-cf` and to everything downstream of it, so before this change
  *no* emitted artifact could enter any LLZK analysis pipeline, and no gate
  noticed (R2-12). Gate G10 is now that gate.

A consequence worth stating, because it closes a finding by construction: there
is no longer a component name to validate. R2-01 was that `LLZK.compile` took a
`name : String` and dropped it unvalidated into `struct.def @{name}`, so
`emit babybear "not a symbol" multiply` emitted `struct.def @not a symbol` with
no diagnostic. A constant is a legal MLIR symbol by inspection. What remains
checkable is a *collision* with a table name, and `diagnoseRegistry` checks it.

Cost: the emitted text no longer names the circuit. Accepted — a Stage-1 module
holds exactly one component, the file name carries the identity, and LLZK's own
convention is that the root is `Main` and subcomponents are named. That makes
this forward-compatible with Stage 2, where subcircuits become named structs
alongside `@Main`.

## D016 — `llzk.fields` cannot be emitted; `llzk.lang` is a string

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S12

`ARCHITECTURE.md` §5 specifies three module attributes. The emitter now produces
`llzk.lang = "clean"` and `llzk.main = !struct.type<@Main>` as written; it does
**not** produce `llzk.fields = [#felt.field<"babybear", 2013265921>]`, and cannot:
declaring a field that LLZK's own registry already knows conflicts with the
built-in definition and `llzk-opt` rejects the module.

Recorded because it is a fact about LLZK 3.0.0 that was learned by trying it and
was otherwise written down nowhere (R2-10). The registry attribute is for fields
LLZK does *not* know; Stage 1 only emits fields it does, by D010, so the
attribute has no role here. If Stage 2 ever needs an unregistered prime, this is
where to start.

`llzk.lang` was previously emitted as a bare unit attribute, which `llzk-opt`
also accepts. That was a silent deviation from the same contract with no decision
entry; it now matches.

## D017 — Check the emitted constraints by comparing polynomials

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S15

Gate G9 reads both sides of the translation into the same normal form and
compares them:

- `ConstraintSet.ofSource` reads the **Clean** circuit, through Clean's own
  `FlatOperation.constraints` and `FlatOperation.lookups` extractors;
- `ConstraintSet.ofModule` reads the **emitted module**'s `@constrain` as data,
  knowing nothing about the circuit behind it, and re-deriving the component's
  shape (input, witness and output counts) from the module alone.

The two meet only at `Poly`, a canonical multivariate polynomial over the
component's cells. The comparison is by multiset, because constraints are a
conjunction and the emitter groups them lookups-first (A6), but multiplicity is
compared, so a dropped or duplicated constraint is a mismatch.

Why polynomials are exact here rather than an approximation: `@constrain`
contains only `felt.const`, `felt.add`, `felt.mul` and cell reads. The non-native
`felt.uintdiv`/`felt.umod` are witness-only and cannot appear, and `ofModule` is
fail-closed on every statement form it does not model. So a syntactic comparison
of normal forms *is* an exact comparison of the two constraint systems.

**What is proved and what is assumed.** `ConstraintSet.ofSource_eqs_iff` proves
that the Clean-side polynomials hold at an assignment exactly when
`ConstraintsHoldFlat` does, and that the remaining polynomials are precisely the
output definitions D008 adds. Every `Poly` operation carries the theorem that it
commutes with evaluation, so two polynomials equal as data denote the same
function. What is *assumed* is that `ofModule` reads the emitted IR the way LLZK
does: `felt.add` is `+`, `felt.mul` is `*`, `felt.const n` is `fromNat n`,
`struct.readm` reads the cell of that name, `constrain.eq a, b` is `a = b`,
`constrain.in t, v` is membership. That is the same kind of assumption as D011,
and deliberately a small and inspectable one.

**One part of it is structurally uncheckable by this design, and R4a-1 named it.**
The emitter encodes a constant as `FiniteField.val c` and `ofModule` decodes it
as `FiniteField.fromNat`, through the same instance, with `fromNat_val` making
the round trip exact. So the constant-encoding convention is a *shared*
assumption of the two readers rather than a cross-checked one — the "neither
reader can see the other's input" property does not extend to it. That is why
D019's class has to be genuinely required: it is what pins the convention, and
nothing downstream can catch it being wrong.

Alternatives considered:

- *A universal preservation theorem about the lowering.* Better, and still the
  eventual target. It needs a simulation argument over the `BuilderM` state
  monad, and R2-05 shows it cannot even be *stated* over `FiniteField` for the
  witness side. G9 as built covers the constraint side for every corpus circuit
  today, with no `sorry`.
- *An SMT determinism check.* Evaluated in S12 and reported as G10. It checks
  determinism of the emitted system, not equivalence with Clean's, and the
  solver step is unreachable from the pinned tools (see `GATES.md`, G10).

**The gate is checked to be falsifiable.** `Test/Constraints.lean` perturbs the
Clean side in each of the ways the emitter could get the emitted side wrong —
dropped constraint, wrong coefficient, duplicated constraint, dropped lookup,
wrong table, wrong circuit entirely — and pins that the comparison goes red for
every one. Without that, a green here would be worth exactly as much as G5–G7's
greens were against Control 4.

## D018 — Validate every translation, rather than verify the translator

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S17

`ConstraintSet.agree` is decidable, so the emitter runs it on its own output and
refuses to return a module that fails. `ConstraintSet.compileSource'` is that
step, and `compile`/`emit` go through it — and through D020's witness half, which
is why they live in `WitnessCheck.lean`.

**Scope, corrected by R4a-3/R4b-4.** This entry used to say "there is no way to
obtain a module from this backend that has not been compared against its Clean
source". That was false: `lower` was public and ran no validation, and the six
`Square_*` corpus entries — which have no Clean circuit behind them — went
straight through it. `lower` is now private, and `lowerRecognized` is the
validated door for a `Recognized` built by hand: it checks the field registry and
the table registry, and says in its own docstring that it is not the fail-closed
entry point for circuits. The accurate claim is the one the theorem supports:
**no module obtained through `compile` or `emit` has gone unchecked.**

`agree_of_compileSource'` is the theorem; `eqs_iff_of_compileSource'` and
`lookups_perm_of_compileSource'` give it meaning by composing it with
`ofSource_eqs_iff`.

Alternative considered and not done: a preservation theorem about `lower` itself.
It is the better artifact — it would say *why* the lowering is right, and make a
bug impossible rather than merely non-emitting — and it is still the eventual
target. It needs a simulation argument over the `BuilderM` state monad, relating
the reader's slot map to the builder's SSA counter through every loop of
`constrainBody`, and the state is behind private fields. That is a session of its
own, and it would have delivered less than this one: before S17, G9 covered five
circuits; after it, every circuit.

What this trades away, stated plainly: a lowering bug shows up as a compile
failure with a "this is a backend defect" diagnostic, not as an unrepresentable
state. That is a worse experience than a verified translator and a much better
one than a wrong module.

## D019 — The backend requires fields whose `val` is the ring representative

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S18

Every recognizer and entry point requires `LLZK.CanonicalRepr F`, a class with
two laws — `val (x + y) = (val x + val y) % size` and the same for `*`.

**This was claimed before it was true.** S18 added the class and put it in six
`variable` lines, and R4a-1 showed that Lean includes a `variable [C F]` binder
only when the *instance itself is used* in the declaration — which it never was,
since `CanonicalRepr`'s fields are mentioned nowhere outside `Field.lean`. Every
binder was silently dropped, the two `omit … in` lines were no-ops, and the
reviewer built a `FiniteField` on `F 5` whose `val` swaps 2 and 3, satisfying
every `FiniteField` law, and compiled a circuit saying `x + 3` into a module
saying `x + 2` with both halves of G9 green. The class is now in the *signatures*
of `recognize`, `compileSource`, `compileSource'`, `compileSourceVerified`,
`agreeCompiled`, `compile`, `emit`, `emitSource`, `witness` and
`Entry.ofSource`, and `#check` confirms it survives elaboration.

The lesson is the same one D005 learned: a claim about what the type system
enforces has to be checked against the elaborated signature, not against the
source that was written with the intention of enforcing it.

This is R2-05, closed rather than recorded. D011's argument rests on
`FiniteField.val x` being "the canonical representative in `[0, p)`, which is
exactly the operand interpretation LLZK's `umod`/`uintdiv` use". `FiniteField`
does not say that: it abstracts over binary fields too, and its laws are
satisfied by any injection into `[0, size)` fixing `0` and `1`. `checkField` pins
`size` only, and size `p` forces `F ≅ 𝔽_p` without forcing *this* `val` to be
that isomorphism.

`CanonicalRepr.val_natCast` derives that `val (n : F) = n % size`, which is what
pins `val` down; without `val_add` the statement is false. The instance for
`F p = ZMod p` is `ZMod.val_add`/`ZMod.val_mul`.

Requiring it at the entry points, rather than recording it in prose, makes a
field that lacks it a *type error* — the same fail-closed treatment D010 gives a
wrong prime, and for the same reason: the failure mode is silently wrong
arithmetic, which no gate can see.

What remains on the LLZK side is that `!felt.type<"babybear">` is
`ZMod 2013265921` and that `felt.umod` reads its operands through `ZMod.val`.
That is part of D017. The point of D019 is that these are now two separate,
stated things rather than one unstated thing spanning both.

## D020 — Check `@compute` the same way, against a tree rather than a polynomial

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S19

G9's other half. `Clean/Backend/LLZK/WitnessCheck.lean` reads the Clean circuit's
witness programs and the emitted `@compute` into a common language, `WExpr`, and
compares them; the comparison is a precondition of emission alongside the
constraint one, so `compile` and `emit` moved again, to that module.

Why a tree and not `Poly`: `@compute` contains `felt.umod` and `felt.uintdiv`,
which no polynomial normal form represents. The comparison is therefore syntactic
on trees — sound, and stricter than the constraint side, since two computations
that are equal but differently shaped would be reported as a mismatch. That is
fail-closed, and in practice the shapes match because both readers are structural
over the same source.

`WExpr.eval_ofWitgen` is the theorem, and it is the one D011 wanted and could not
state before D019: Clean's `ofNat (mod (val x) (const c))` denotes exactly what
`WExpr.eval` says `felt.umod` denotes. `WExpr.eval`'s `umod`/`uintdiv` cases *are*
the D017 reading of those operations, so the two sides of D011's argument are now
connected by a theorem rather than by prose.

Two things this does not do:

- It compares expressions cell by cell. Lifting that to "the emitted `@compute`
  produces the vector `FlatOperation.dynamicWitnesses` produces" additionally
  needs the block-prefix argument R2-03 is about, which `Analyze` enforces rather
  than proves. G5–G7 remain the evidence for the whole-vector statement, now on
  30 vectors including three outside `Addition8FullCarry`'s `Assumptions` — the
  gap R2's C5 recorded.
- The Clean-side reader is deliberately *not* `Witness.ofFExpr`, which is the
  emitter's own recognizer; using it would make the comparison a self-check. It
  is a separate traversal whose correctness is proved, which is the property
  `ofFExpr` has only by inspection.

## D021 — S20 is blocked on where the private boundary goes, not on effort

**Status:** accepted — option (1); the proof itself is scheduled, not open
**Date:** 2026-08-01
**Enacted by:** the S20 attempt

D018 and D020 record that G9 *validates each translation* rather than verifying
the translator, and name the preservation theorem about `lower` as the thing that
would replace it. An attempt at its reusable core — that running
`FieldExpr.lower` on an expression and then reading the emitted statements yields
that expression's polynomial — ran into a structural obstacle worth recording,
because it is not the one the earlier entries implied.

The obstacle is **not** the `BuilderM` state monad. It is that every handle the
proof needs is private:

- `Value`'s constructor, so a proof cannot name the value an emission returns;
- `Builder.fresh`, `Builder.emit` and `Builder.emitValue`, so it cannot unfold
  what the typed emitters do;
- `BuilderState`'s fields, so it cannot state what the state became.

All of them are private *on purpose*: they are D005's first invariant, which
R4b-3 tightened only hours before, and un-privating them would restore exactly
the hole the reviewer exploited. Meanwhile `FieldExpr` lives in
`Expression.lean`, which imports `IR.lean`, so the proof cannot live in either
module.

So S20 needs a decision before it needs a proof, and there are three shapes:

1. **Move `FieldExpr` into `IR.lean`** and prove there. Keeps every invariant;
   costs the clean separation between the accepted source language and the
   emitter IR, which D009 is about.
2. **Give `IR.lean` a proof-facing interface** — a read-only `Builder.run`, and
   `Stmt`-level lemmas about each typed emitter, stated inside `IR.lean` and
   exported. Keeps both boundaries; costs a second API to maintain in step with
   the first.
3. **Restructure the emitters as pure functions** from `(nextIndex, args)` to
   `(statements, value)`, with the monad as a thin wrapper. Makes the theorem a
   plain structural induction with no state reasoning at all, and is probably the
   right answer; costs a rewrite of `IR.lean` and `Expression.lean`.

**(1) is the one to take, and the first recommendation of (3) was wrong.**

Purity does not remove the need for `Value`'s private constructor: a pure
`FieldExpr → Array Stmt × Value × Nat` still has to *build* the `Value` it
returns, so it still has to live in `IR.lean`. Routing around that with an
intermediate plan type over bare `Nat` indices only moves the realization step,
and buys a second instruction type to keep in step with `Stmt`. So (3) collapses
into (1) for the one function that matters, and (1) is the honest way to say it.

Concretely: move `FieldExpr`, `Env`, `LowerM` and `FieldExpr.lower` — about sixty
lines, none of which depend on anything outside `IR.lean` — into `IR.lean`, and
prove there. `Expression.lean` keeps `ofExpression`, the bridge from Clean's
`Expression`, which is the part that genuinely belongs on the source side.
`Circuit.lean`'s five call sites are unaffected because the signature does not
change.

The cost is module cohesion: `IR.lean` becomes "the emitter IR, the closed
expression language it emits, and the proof that the two agree" rather than just
the first. D009 calls `FieldExpr` "a closed language containing only what the
backend can emit", which is a description of part of the emitter, so this is
arguably where it belonged.

This is a session of its own with its own review. Two
partial artefacts from the attempt are *not* kept, deliberately: a `readStmt`/
`readStmts` pair and their two lemmas compiled cleanly, but a lemma with no
theorem above it is the speculative generality R2-08 removed elsewhere, and it
would have to be rewritten under whichever shape above is chosen.

**The blast radius, measured rather than guessed**, so the next session starts
from a number: 43 call sites of the typed emitters, across four modules
(`Expression`, `Circuit`, `RendererFixture`, `Test/Constraints`), and exactly two
references to `BuilderM`/`BuilderState` outside `IR.lean` — one of which is a
docstring. The monad is already almost entirely contained; what leaks is the
*emitter API*, and (3) changes its shape rather than its users' logic. That is a
contained refactor, and it is contained *because* of the encapsulation that
blocks the proof today.

Why it is not done here: it rewrites the core of a system that currently passes
eleven gates and has just been through two independent reviews, at a point where
no further review is available. The order that respects that is: make the shape
decision, refactor under G0–G10, get it reviewed, then prove. Not the reverse.

Recorded because "S20 is large" was an estimate, and this is the actual reason
and the actual size.
