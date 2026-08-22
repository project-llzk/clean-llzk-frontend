# Clean → LLZK decision log

## D001 — Host the first frontend in Clean

**Status:** accepted  
**Date:** 2026-07-31

Implement the first frontend as pure Lean under `Clean/Backend/LLZK/`. Emit a
small, deterministic textual LLZK subset and validate it with the pinned C++
LLZK 3.0 tools.

This initially avoided coupling Clean's Lean 4.30 toolchain to the project VeIR
fork on 4.31-rc2 or upstream VeIR on 4.32.2. S25 moved Clean to Lean 4.32.2 and
remeasured that rationale: the toolchain mismatch is no longer decisive, but
the accepted project VeIR pin still has no Struct or Array LLZK dialect and its
opcode definitions explicitly defer `constrain.in` and `function.call`.
Consequently the small textual seam remains the only complete host for the
frontend's accepted output surface.

## D002 — Use `alexanderlhicks/clean` as the project home

**Status:** accepted for development; superseded for the public destination by
D027

**Date:** 2026-07-31

The fork `alexanderlhicks/clean` owns the frontend implementation, fixtures,
conformance harness, decisions, pins, and cross-session handoffs.

Do not fork LLZK unless implementation uncovers a required LLZK dialect,
verifier, or witness-tool change.

## D003 — Keep VeIR non-blocking

**Status:** accepted; reaffirmed by S25
**Date:** 2026-07-31

VeIR initially consumes the frozen `.llzk` fixture corpus as an independent
round-trip/checking track. A direct dependency is reconsidered only after
toolchains and required LLZK dialect coverage align.

S25 rechecked the accepted project VeIR revision
`eae1c27e7842c0503233ec99155c39791bd5f502`: it is still on Lean 4.31.0-rc2,
has LLZK Felt/Bool/Global/Function coverage, but no Struct or Array dialect, and
marks `constrain.in` and `function.call` as deferred in `Veir/OpCode.lean`.
Clean's move to 4.32.2 therefore removes one integration obstacle without
removing the binding dialect gap.

## D004 — Fail closed on source semantics

**Status:** accepted; witness-arithmetic basis amended by S25/D026 and S26/D033
**Date:** 2026-07-31

Clean's current `U64Expr` is wrapping u64 arithmetic and is not generally field
arithmetic. The frontend accepts only recursively bounded expressions covered
by D033's theorem and refuses the rest. D026 records the narrower bridge S25
temporarily preserved; the pre-S25 decision used unbounded `NExpr` instead.

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

**Status:** accepted for the pre-S25 `NExpr` design; superseded by D033 for the
current `U64Expr` lowering
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
`ExportTable.Certifies` in `Clean/Backend/LLZK/Certificate.lean` is that `Prop`.
S28 generalized it from scalar values to ordered `RawTable` rows, including
name and arity. The discharge theorems cover every table currently exported:

- `ofStatic_certifies` — for *any* `StaticTable`, at any `ProvableType` row
  arity. `ofStatic` computes the rows from the table's own `row` function, so
  the only content is that the ordered canonical representation loses nothing.
- `byteTable_certifies` — for `Gadgets.ByteTable`, the case this entry's
  follow-up said was open because it inlines its `StaticTable` and naming that
  breaks unrelated proofs. It does not need naming: `StaticTable.toTable` defines
  `Contains` from the `row` function alone, and `contains_iff` already relates
  that to `x.val < 256`. `Examples.byteTable_certified` closes the loop.
- `byteXorTable_certifies` — for the full 65,536-row, arity-three
  `Gadgets.Xor.ByteXorTable`, relating each ordered field triple to its emitted
  canonical natural row.

`certified_membership` is the payoff, and it is where the range check S08 added
does its work: for a certified table with canonical values, Clean's `Contains`
holds of an ordered row exactly when that field row is one of the rows the
emitted array holds — which is what the emitted `constrain.in` asserts.

**The certificate is carried, not enforced — and an earlier version of this
entry said otherwise.** `CertifiedConfig` holds `CertifiedTable`s and is what
the public entry points take (S24; it was `Config.ofCertified`, which erased
them, when this was written). `Examples.withBytesAndXor` carries both current
lookup tables, so each has its proof next to its rows and changing the rows
breaks the build. But R4a-2 broke the
"cannot be called without a proof" reading: the caller chooses *both* the export
table and the Clean table, and nothing ties the latter to the table the circuit's
`.lookup` names — that is a `RawTable`, resolved by name, and `Table.toRaw` has
erased which `Table` it came from. `selfTable e` with
`Contains _ row := canonicalRow row ∈ e.rows` certifies any rows at all, and the reviewer
compiled `Addition8FullCarry` with a one-row `@Bytes`.

So the residual is precise: the obligation is stated, and proved for every table
in use; the compiler cannot demand it. Closing that needs the `Table` to survive
into `Lookup`, which is a change to Clean's core rather than to this backend.

**And the bridge is now composed, not just available.** `certified_membership`
was proved and instantiated nowhere, with its canonicity hypothesis left to the
caller (R4a-6). `ExportTable.values_lt_prime_of_diagnose` discharges that
hypothesis from the check the compiler already runs — the one S08 added for
R2-02 — and the byte/ByteXor lookup theorems compose the two. For the original
one-column case:

> `Gadgets.ByteTable.Contains t x  ↔  ∃ n ∈ @Bytes's values, fromNat n = x`

The left-hand side is Clean's lookup constraint; the right-hand side is what the
emitted `constrain.in %Bytes, %x` asserts. S28 states the same relation over an
ordered array of field values and instantiates it at `And8`. Everything between
them is a theorem.

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

**Status:** superseded by D034; retired by S28
**Date:** 2026-08-01
**Enacted by:** S06

A wider table needs an `array.new` query and a multi-dimensional `constrain.in`,
neither of which the emitter IR has. Rather than guess at that encoding, arity
other than 1 is refused with a diagnostic that says what it would take. Clean's
`ByteTable` — the Stage-1 target — is single-column.

S28 performed the required exact-pin probe and implemented D034. Wider static
tables are now accepted as ordered rows; arity zero, row-width mismatches, and
malformed row types remain refused. This entry remains as the historical reason
the earlier frontend failed closed rather than guessing.

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

The comparison uses `llzk-witgen --check-output` in both `full-witness` and
`public` scopes, so a disagreement is a non-zero exit rather than two JSON dumps
for a reader to diff. The public check was added on 2026-08-22 because
full-witness JSON does not distinguish signal from public members. G7 is carried
inside G5 and G6 rather than being a separate run.

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

`agree_of_compileSource'` is the theorem. The original convenience wrappers
`eqs_iff_of_compileSource'` and `lookups_perm_of_compileSource'` were retired in
the 2026-08-22 cleanup because the active soundness chain consumes the more
general `eqs_iff_of_agree` and `lookups_perm_of_agree` directly. Those compose
the same data-level agreement with `ofSource_eqs_iff` and the lookup certificate
bridge without coupling it to one compiler entry point.

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
fail-closed, and the shapes match because both readers are structural over the
same source — except for bare copies, which the module genuinely does not
distinguish and which both sides therefore canonicalise away. See "Canonicalising
copies" in `WitnessCheck.lean`; R5c found that case by having a correct module
for a proved `FormalCircuit` refused. "In practice the shapes match" was too
strong: it is what stopped anyone testing the refusal branch against real emitter
output.

At S19, `WExpr.eval_ofWitgen` proved that Clean's whole division/modulo shapes
denoted exactly what `WExpr.eval` says `felt.umod`/`felt.uintdiv` denote. S26
extends the same independent-reader theorem to every D033-admitted structural
u64 tree and adds `eval_bitsOf`; the new non-field cases are the D017 reading of
the corresponding LLZK operations.

The S19 theorem carried no canonicity content: it was stated over `FiniteField`
and held for a permuted `val` (R5b-5). The S26 extension deliberately requires
`CanonicalRepr`, because bounded u64 addition and multiplication need its
`val_add`/`val_mul` laws. The historical correction still matters: the original
whole-shape theorem and D019's ring-representative guarantee were separate
claims, even though the structural theorem now consumes both.

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

## D021 — Proof placement for S20 (historical; partial proof retired)

**Status:** superseded on 2026-08-22 — option (1) remains enacted; the partial theorem was retired
**Date:** 2026-08-01
**Enacted by:** the S20 attempt

**Maintenance note.** The design conclusion remains useful: any proof that
needs to expose private builder state belongs beside that state in `IR.lean`.
The particular `FieldExpr.lower_spec` subsequently proved there was not a
translator-preservation theorem. R5 showed that five grossly wrong lowerings
satisfied it, it did not compose with function assembly, and no code or proof
consumed it. The 2026-08-22 audit removed the theorem and its private
`ExprAlgebra`/assignment reader (about 390 lines). The chronology below explains
why it was attempted; it does not describe a current assurance artifact.

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

**One more fact, from carrying the move out and then setting it aside.** The move
itself is mechanical and keeps every gate green — that was verified end to end.
What stops the proof being *developed* against it from outside is stronger than
expected: `BuilderState`'s constructor is private too, so the theorem's
*statement* cannot be written outside `IR.lean` at all. `Builder.run start (lower
…)` is expressible, but the frame lemma every sequencing case needs must mention
`{ nextIndex := …, stmts := … }`, and cannot.

So the work happened inside `IR.lean`. At the time, `FieldExpr.lower_spec`
proved that running the lowering from a fresh index and
reading the emitted statements back recovers the expression's denotation at the
value returned, together with the bookkeeping — the index only advances, every
statement defines an index in the range consumed, and the returned value is in
scope. Axioms: `propext`, `Classical.choice`, `Quot.sound`. No `sorry`.

Four things established, recorded because they are what made it tractable and
because the earlier framing predicted the opposite:

- **The monadic machinery reduces definitionally.** `rfl` discharges
  `Builder.run start (FieldExpr.lower ctx ty env (.const c))`. No `simp`
  incantation for `ExceptT`/`StateT` is needed, which was the risk D018's
  "simulation argument over the `BuilderM` state monad" implied.
- **The reader's stability lemmas are short**: that reading one statement changes
  only the index it defines (`readStmt_ne`), that a list defining no index equal
  to `i` leaves `i` alone (`readStmts_ne`), and the `bound`-shaped corollary
  (`readStmts_below`). The second is what makes an earlier subexpression's value
  survive a later one's emission.
- **`Builder.run_bind` is the linchpin, and it holds.** Sequencing is *not* `rfl`
  — the match needs the scrutinee's shape — but it falls to one case split. With
  it, every inductive case is a rewrite rather than a monadic unfolding.
- **`Builder.run_emitValue` is the other half**, and it *is* `rfl`: one emission
  collapses to allocate-append-return in a single rewrite. Unfolding `fresh` and
  `emit` separately instead sends `simp` into a loop against
  `Array.push_eq_append`. Do not do that.

The whole proof is about 180 lines and needed no simulation argument, no frame
lemma stated by hand, and no reasoning about `StateT` beyond those two lemmas.
D018's framing — "a simulation argument over the `BuilderM` state monad" — was
the wrong shape, which is why it read as a much larger obstacle than it was.

**Stating the reading claim conditionally on the expression having a denotation**
is what makes `uintdiv`/`umod` free: they are witness-only, they denote nothing
in an `ExprAlgebra`, and the claim is vacuous for them. That removes the
freshness side condition an unconditional statement would need.

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

## D022 — The unchecked lookup-table path is private, loud, and confined

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S22, closing R5's X1

`Config`'s constructor is now private. The only public way to supply lookup
tables is `Config.unsafeWithTables`, and `Config.ofCertified` is the wrapper
that supplies an `ExportTable.Certifies` proof. G12
(`scripts/llzk/check-confinement.sh`) fails if any non-test module names the
unsafe one.

R5's X1 was not that an unchecked path existed — D012 says the compiler cannot
check the rows, and the negative fixtures must be able to build malformed
registries. It was that the unchecked path was the *quiet default*:
`{ field := .babybear, tables := #[fatBytes] }` compiled `Addition8FullCarry`
into a module admitting `w0 = 300`, which Clean's `ByteTable` rejects, with every
gate green.

Alternatives rejected:

- *Delete the unchecked path.* It would delete the negative fixtures, which are
  the only tests of the registry diagnostics.
- *Keep it and rely on the `ConstraintSet.globals` conjunct.* That was the R4
  answer and it does nothing: both sides read `cfg.tables`, so the conjunct is a
  tautology. Its docstring now says so.

What is still true and unchanged: nothing ties an `ExportTable` to the `Table` a
`RawTable` erased except a proof someone writes. The change is that the proof is
now the path of least resistance and its absence is greppable and gated.

**Superseded in part by S24, which executed `sessions/S23-x1-closure.md`.** The
sentence above — "greppable and gated" — was the honest description of a
convention, and S23 said why that is not closure: `Config.ofCertified` demanded
the certificates and then *erased* them, so what reached `compile` was a plain
`Config`. The five public entry points in `WitnessCheck.lean` (`verify`,
`compileSourceVerified`, `compile`, `emit`, `emitSource` — R7-15 corrected an
earlier "seven", which counted the two theorems) now take a
`CertifiedConfig F`; `ofCertified` is retired; there is no public function from a
`Config` to a `CertifiedConfig`. `Config` and `unsafeWithTables` both stay, and
both stay confined by G12, because the negative fixtures must be able to build
malformed registries and `Analyze`/`Circuit`/`Constraints` need a plain `Config`
internally — what changed is that no *supported* compile or emit path accepts
one. ("Nothing public" was also too strong: `compileSource`, `compileSource'`
and `lowerRecognized` are Lean-public and take a plain `Config`; G12 is what
gates any new caller of them — R7-13.)

Two consequences worth naming. The type is indexed by `F`, which `Config` was
not, because a `CertifiedTable F` mentions a Clean `RawTable F`; that is why
`Examples.babybear` is now a `CertifiedConfig (F pBabybear)` rather than a
field-agnostic value. S28's `RawTable` carrier lets arity-one and arity-three
certificates coexist. And the generic half of `TableCert.lean` moved to
`Certificate.lean`, so that `WitnessCheck.lean` can name `CertifiedConfig`
without the compiler's public surface transitively importing
`Clean.Gadgets.ByteLookup`.

`GAPS.md` item 1's second half — tying an `ExportTable` to the circuit's own
`Table` — is untouched and still needs a change to Clean's core.

## D023 — The worktree lock is a gate, CI claims it, and stale locks are not taken silently

**Status:** accepted
**Date:** 2026-08-02
**Enacted by:** S24

`scripts/llzk/e2e.sh` calls `worktree-lock.sh require` before G11. Three
questions had to be answered to make that safe, and this records all three.

**Why `e2e.sh` and not a lighter check.** It is not read-only: G2 deletes and
rebuilds `.lake/llzk`, and a run's evidence is attributable to a commit only if
one session owned the tree while it ran. S22's evidence file carries a caveat
saying its `PASS` could not be attributed to its own commit; that is the cost
this removes.

**Why CI claims rather than being exempted.** The alternative was for `require`
to treat a non-interactive environment as exempt. Every predicate available for
"no contention here" — no tty, non-interactive, `CI=true` — is also true of the
agent sessions on the development machine, which are the writers that collided
three times on 2026-08-01. A mis-set exemption is invisible, because the gate
still passes. The `llzk-e2e` job gets a claim step and a job-level
`LLZK_SESSION`, which on a fresh ephemeral checkout always succeeds: two lines,
no new failure mode, and CI exercises the developer's path rather than a bypass
around it. `llzk-harness` needs nothing; none of its three scripts write to the
worktree.

**Why `reclaim` is now separate from `claim`.** Wiring the lock in exposed that
it did not protect the sessions it was written for. Identity defaulted to the
POSIX session id, which under an agent harness is the *command*: S24 claimed the
lock and the very next command was told it did not hold it, with `status`
reporting the fresh claim as stale and reclaimable. `claim` used to take a stale
lock silently, so a second agent session would have been told the tree was free —
the S22 collision unchanged, but now with a lock file to point at afterwards.
So ownership no longer transfers without someone saying it should, and
`LLZK_SESSION` is the documented identity for agent sessions, named in
`require`'s own refusal rather than only in prose.

Alternatives rejected:

- *Infer a stable identity by walking the process ancestry.* Every rule that
  makes an agent session stable also merges distinct terminal panes under a
  shared `tmux` server, or breaks on a wrapper process. A lock whose identity
  rule needs a paragraph of caveats is worse than an explicit variable.
- *Keep the silent reclaim and rely on discipline.* Discipline is what failed
  three times.

Consequence: a lock left behind by a dead session now needs one deliberate
command, `reclaim`, instead of resolving itself. That is the intended trade.

**That last sentence was false for every session this entry is about, and R6 hit
it on the first line of `CURRENT.md`'s "Next session".** `lock_is_live` decides
liveness by `kill -0`, which needs a numeric session id; an `LLZK_SESSION` id is
opaque, and the function fails *closed* — unknown means held. So for exactly the
identities D023 introduced, `reclaim` answered "is live; reclaim is only for a
lock whose owner is gone", `claim` printed the live-holder refusal whose only
advice is "wait", and `status` reported an assumption as a fact. There was no
deliberate command; there was `rm`, which this entry does not mention. S24's own
lock sat on the tree for two days and R6 had to delete it.

G11 did not see it because all three of its stale-lock cases record owner
`999999` — a numeric id, the one case that worked.

## D024 — `reclaim --from` supplies the observation the machine cannot make

**Status:** accepted
**Date:** 2026-08-04
**Enacted by:** R6

The repair is not to guess liveness. Every rule that would decide it for an
opaque id is the same rule D023 already rejected. It is to let the operator
supply the missing observation, in a form an accident cannot produce:

```
bash scripts/llzk/worktree-lock.sh reclaim '<what you are doing>' --from '<owner-id>'
```

`--from` must equal the *recorded* owner, so a value copied out of an earlier
refusal cannot displace a holder that arrived since; and having to copy it at all
is the deliberate act, in the same spirit as `reclaim` being separate from
`claim`. Numeric owners keep the automatic path: `reclaim` with no `--from` still
takes a lock whose owner this machine can prove dead, and still refuses one it
can prove alive.

Two smaller things the same repair fixes, both of which were reporting an
assumption as a fact:

- `status` now distinguishes "held, liveness undecidable (LLZK_SESSION id)" from
  "held", and names the `--from` that would displace it;
- `claim`'s refusal for an opaque owner now offers that route instead of only
  "wait or take your own worktree", which for an unreclaimable lock was advice to
  wait forever.

G11 gained six cases covering the opaque path, and the existing "reclaim while
the holder is live" case was split: it had been written with `LLZK_SESSION=owner`,
so it was testing the undecidable path while claiming to test the live one. The
provably-live case now records this shell's own POSIX session id.

The general lesson is D005's and D019's again, in a third place: a claim about
what a mechanism guarantees has to be checked against the case the mechanism was
built for, not against the case that was easiest to write a test for.

## D025 — Align with upstream Clean before any capability increment

**Status:** accepted
**Date:** 2026-08-04
**Enacted by:** S25; S26 enacted the next bounded structural increment

Two capability increments were about to be built at Clean `1e563b9c`: a recognizer
for the bit-decomposition shape `ofNat (mod (div (val x) (const 2^i)) (const 2))`,
and then bitwise `land`/`lor`/`lxor`. **Both would have been discarded on the next
bump**, and not because they were early — because they target an IR upstream has
replaced.

Measured against `upstream/main` = `0e53b9f2` (Lean 4.32.2, merged 2026-08-04,
70 commits ahead of our base; `Clean/Circuit/` +878/−194 across 15 files):

- **`Witgen.NExpr` is deleted.** It is replaced by `U64Expr` — bounded, and
  documented as *"All operations wrap modulo `2^64`."* `land`/`lor`/`lxor` live
  there now, so an increment written against `NExpr` targets a type that no longer
  exists.
- **`VExpr.bitsOf {n} (x : FExpr F)` exists**, with `BExpr.bit x i` beside it. Bit
  decomposition is a *constructor* upstream, so the recognizer would have been a
  workaround for something already fixed.
- `FExpr` also lost `envGet` and renamed `ofNat` to `ofU64`; `BExpr` gained
  `flt` and `bit`; `VExpr` gained `envRange` and `bitsOf`; and `Step.letN`
  became `letU`. R7 corrected an earlier inventory that wrongly put `lor` on
  `FExpr` and described pre-existing constructors as new.

So the order is: bump (S25), rewrite the witness recognizer structurally against
`U64Expr` (S26), add multi-column tables (S28), then promote the newly supported
gadgets. S27 was returned for re-scoping by R7: its GF(2) submission has no
bitwise witness operations and is blocked by `letF`, not S26. Doing capability
increments before the bump still means targeting a deleted IR and throwing the
work away.

**What this does to D011, precisely.** D011's argument is *"`NExpr` denotes
unbounded `ℕ`, so lowering piecewise is wrong; therefore match two whole shapes."*
Against a fixed-width sort that argument lapses and structural lowering becomes
available. But D011's *problem* is replaced rather than removed: a `u64` does not
fit in a babybear felt. `p_babybear ≈ 2^31`, and wrapping modulo `2^64` is not
reduction modulo `p`; only bn254 and grumpkin hold a `u64` outright. So S26 owes a
width or bound analysis, and it owes it as a theorem or a refusal — D011's own
history is the warning, since R2-05 found its central side condition unstated for
four sessions and closing it took a whole class (D019).

**One thing this does not settle, and should be re-checked rather than assumed.**
D001 justified the textual-MLIR seam partly by *"Clean's Lean 4.30 toolchain
[versus] the project VeIR fork on 4.31-rc2 or upstream VeIR on 4.32.2"*. If Clean
is now on 4.32.2 that half of the argument lapses, and in-process interop becomes
a live question again. It is a smaller shift than it sounds: VeIR's missing
dialects — Struct, Array, `constrain.in`, `function.call` — are the binding
constraint, not the toolchain, and D003 rests on those. Re-measure both before
reopening D003.

**S25 remeasurement.** The accepted project VeIR pin remains
`eae1c27e7842c0503233ec99155c39791bd5f502` on Lean 4.31.0-rc2. Its LLZK
dialect tree has Felt, Bool, Global, Function, Include, and String modules but
no Struct or Array modules; `Veir/OpCode.lean` explicitly defers
`Constrain.in` until Array types land and `Function.call` until its call phase.
The toolchain half of D001's rationale lapsed, while D003's dialect-coverage
boundary was reaffirmed.

**Why this entry exists at all.** The finding came from checking upstream instead
of planning against a local pin — the same lesson the CI paragraph in `CURRENT.md`
records at the cost of two days. A version pin is a claim about the world, and it
goes stale silently.

## D026 — Preserve the narrow u64 shapes with an explicit field-size boundary

**Status:** accepted as the S25 compatibility boundary; superseded for current
structural lowering by D033

**Date:** 2026-08-21

**Enacted by:** S25

Upstream replaced unbounded `NExpr.val` with `U64Expr.val`, whose evaluation is
`UInt64.ofNat (FiniteField.val x)`. It therefore truncates modulo `2^64`.
Translating the old whole shapes to `ofU64 (div/mod (val x) (const c))` preserves
their syntax but not their generic meaning: the emitted `felt.uintdiv` and
`felt.umod` operate on the full felt representative.

S25 keeps the accepted syntactic subset unchanged and makes the theorem boundary
visible. `WExpr.eval_ofWitgen` now requires
`FiniteField.size F ≤ 2^64`; its proof uses that every representative is then
below the truncation modulus. This covers babybear, koalabear, mersenne31, and
goldilocks. It does not cover bn254 or grumpkin for `val`-rooted division/modulo
witnesses. Their field-registry entries and circuits without those witness
shapes are unaffected.

This is a real semantic limitation, not an LLZK-tool failure. G9's two readers
still agree structurally because both map the source shape to the same `WExpr`,
and the wide-field corpus entries exercise multiplication rather than this
bridge. Green gates therefore cannot recover the missing theorem premise.

Only bn254 and grumpkin have prime greater than `2^64` and can represent every
u64 directly as a felt. Goldilocks and the three roughly 31-bit fields make the
source bridge non-truncating in the other direction but cannot host arbitrary
u64 values without a range/limb policy. S26 must choose and prove such a policy,
change the emitted semantics to truncate, or refuse the wide-field bridge; S25
does not silently choose among those capability designs.

## D027 — Prepare an organization-owned public home

**Status:** accepted as a milestone; publication not yet authorized

**Date:** 2026-08-21

**Enacted by:** `PUBLIC-READINESS.md`

The personal fork remains the development and staging remote while the project
builds a release candidate. The intended public destination is an
organization-owned repository under `project-llzk`, where it can be listed with
the Circom, Halo2/PLONKish, Airbender, and Noir frontends.

Moving early would have made repository ownership look settled while the code
still rested on a stale Clean base, had only one proved headline example in the
full external-tool corpus, and left the renderer's constraint-only statements
with one line of defense. S25 and A5 have since closed the first and third
conditions; the impactful-example and final-review requirements remain.
Repository transfer is therefore still an exit action, not a way to create the
milestone.

The release candidate must satisfy `PUBLIC-READINESS.md`: current upstream
Clean alignment, an explicit review of the moving LLZK pin, an end-to-end
bitwise example family, renderer round-trip assurance, green falsifiable gates,
public documentation, and a final frozen-tree review. The personal fork
decision in D002 remains valid for staging until then.

Two publication topologies remain available:

1. transfer or recreate the GitHub fork as `project-llzk/clean`, preserving the
   fork relationship but giving a broad upstream project an ambiguous LLZK name;
2. create `project-llzk/clean-llzk-frontend` with the full Git history and keep
   `Verified-zkEVM/clean` as `upstream`, which is clearer in the organization's
   frontend list but may not display GitHub's fork badge.

Prefer the descriptive repository unless preserving the GitHub fork relation is
explicitly required. Creating the repository, changing remotes, pushing,
transferring, and organization settings remain reserved for a separate explicit
publication decision under `ORCHESTRATION.md` section 11.

## D028 — Fail closed after reading the rendered constraint surface back

**Status:** accepted

**Date:** 2026-08-21

**Enacted by:** A5

G9 compares the typed `Module` with the Clean source before rendering. R6 and R7
demonstrated the remaining seam: the renderer could redirect a member read,
drop every `constrain.eq`, or emit an empty `@constrain`, and every pinned LLZK
binary gate would remain green. The toolchain checks well-formedness, not that
the concrete constraint program is the typed one G9 approved.

The supported renderer reads back every protected form at that seam:
`global.def`, `struct.readm`, `array.new`, `constrain.eq`, and `constrain.in`.
The reader
extracts SSA indices, the member name, operand order, and complete rendered type
syntax from inside the concrete `@constrain` function. The type reader rebuilds
`Ty` rather than sharing `Ty.render`, so a field-name or nested-array rendering
bug does not affect both sides of the comparison. `Module.render` returns an
`Except` and releases text only when the extracted sequence equals the typed
projection; `EmitMain` and `renderResult` both go through it.

The theorem `Module.render_constraintSurface` states the enforced round trip.
Direct parser controls and mutations make its success premise non-vacuous and
its failure direction visible. This closes GAPS section 2 at the backend's
concrete-text seam without claiming a formal LLZK semantics: D017 remains, and a
future table/constraint-surface constructor must extend this reader or reopen
the claim. S28 extended the original A5 surface with the global and row
constructor when multi-column membership made them semantically load-bearing.

## D029 — Make copy canonicalisation a proved semantic step

**Status:** accepted

**Date:** 2026-08-21

**Enacted by:** A7

A bare witness copy has no fresh SSA definition in the emitted module, so the
source and module readers must identify the copy cell with the variable it
copies. The comparison was already pinned by copy chains and non-copy red
controls, and `WExpr.eval_rename` plus `WExpr.eval_congr` proved the surrounding
renaming facts. One premise remained prose: inspecting a mutable array update
was the only argument that every chosen representative denoted the variable it
replaced.

`CopyCanon.step` now makes that update a named semantic operation. It renames the
new witness expression through the accumulated representative function and
extends that function only at the new cell: to the copied representative for a
bare `cell`, or to itself otherwise. `CopyCanon.run` folds that operation over
the witness-program list, and `WitnessSet.ofSource` calls `run` directly.

`CopyCanon.step_preserves` proves that if the old representatives preserve
values and the new witness cell denotes its unrenamed program, the extended map
preserves values for every variable. Its proof composes the two existing
renaming theorems and distinguishes the bare-copy and computed-cell cases.
`CopyCanon.run_preserves` inducts that result through the entire list from the
identity map. This closes GAPS section 8's copy-canonicalisation premise without
strengthening the separate whole-vector witness claim or D017's reading of
LLZK.

## D030 — Generate public example claims from the conformance corpus

**Status:** accepted

**Date:** 2026-08-21

**Enacted by:** public-showcase increment

The public-readiness contract requires a small checked example table. Copying
the corpus names and counts into Markdown would immediately create the kind of
second source of truth that repeatedly made `CURRENT.md` overstate or understate
coverage during R2–R7.

`Showcase.markdown` therefore derives each row's name, field, vector count, and
G9 source-agreement status from `Corpus.corpus`. The only editorial input is an
exhaustive purpose label: an unknown corpus entry makes generation fail, so
adding an artifact also requires deciding what a public reader should learn from
it. Failed modules, empty vector sets, and failed or half-present agreement
results likewise refuse generation.

`ShowcaseMain.lean` materializes `doc/llzk/EXAMPLES.md`. The full gate regenerates
the page and requires byte equality, while `Test/Showcase.lean` pins the corpus
ordering, denominator, vector total, source-backed count, and purpose coverage.
The prose remains intentionally honest about D017, the caller-to-circuit table
identity gap, and selected rather than exhaustive coverage.

## D031 — Pin CI dependencies and make self-hosted benchmarking opt-in

**Status:** accepted

**Date:** 2026-08-21

**Enacted by:** public CI hardening increment

The inherited workflows selected action code through moving release tags,
selected hosted images through `ubuntu-latest`, and let the Plonky3 job follow
Rust `stable`. That is inconsistent with a frontend whose source, theorem
environment, external verifier, and evidence are otherwise tied to exact
inputs. It also made workflow review transient: the same repository commit
could execute different third-party code later.

Every external action reference is now a reviewed 40-character commit SHA,
hosted jobs name Ubuntu 24.04, Plonky3 names Rust 1.98.0, and the main workflow's
token default is explicitly read-only. `check-actions-pinned.sh` fails closed on
regressions and G11 exercises both its negative and positive directions; merely
adding a checker without red controls would repeat the harness failure that
motivated G11.

The LLZK job also installs the public substituter and trusted key already
accepted in `PINS.md`, with `--max-jobs 0`. The staging run's 4h23m source build
was both an availability risk and an uncontrolled fallback. The new rule is
cache hit or explicit failure; the organization run remains responsible for
proving anonymous access and measuring the actual improvement.

The inherited self-hosted benchmarks are a different trust boundary. They run
pull-request code in a networked container and use persistent caches, while the
container base and elan bootstrap are not yet immutable. Deleting the benchmark
machinery would erase useful prior work, but enabling it in a public
organization repository would overstate its readiness. All benchmark entry
points therefore require the repository variable `CLEAN_BENCH_ENABLED` to equal
`true`, and publication keeps it unset. A later enablement requires an explicit
runner-owner and threat-review decision; it is not part of the four release
checks.

## D032 — Advance the LLZK tool pin after an unchanged same-tree matrix

**Status:** accepted

**Date:** 2026-08-21

**Enacted by:** L0

L0 compared the previously accepted
`5db6f8f9baaa40787a1a40625796497445f2da36` tools with exact current-main
candidate `25fb3740ea3465c9129a06289297bb4f0554b7a5` on frontend commit
`782160ddc4ed57f9dbfecebf655f6d220381f43b`. Both Nix outputs were materialized
by immutable flake reference with `--max-jobs 0`; the candidate came entirely
from the accepted public cache. Live `main` was re-queried immediately before
the build and still matched the inventoried candidate.

Both tools passed the unchanged G0-G12 matrix: 12 circuits, 33 vectors through
both witness backends, 2 renderer fixtures, all 14 modules through the product
pipeline, the same 10-lowered/4-declared-out-of-scope SMT split, all six field
probes, and all 53 harness red paths. The candidate added the expected WTNS
help surface but did not change the full-witness JSON contract, accepted
artifacts, diagnostics, fixtures, counts, or theorem closure used here.

Advance to `25fb3740`. The delta contains relevant correctness and maintenance
value: witness generation now honours the selected output scope; redundant
read/write elimination correctly handles dynamic aliases and observed writes;
poly lowering fixes non-Felt equality and replaces an assertion failure with an
error; and `BUILD_TESTING=OFF` is repaired. These affect exactly the witness,
memory, SMT, transform, and reproducibility surfaces L0 exercised.

The costs do not disappear: the 25-commit transform surface is large, no newer
tag supplies a release contract, and both inputs still report version 3.0.0.
The controls are the immutable source SHA, public-cache provenance, complete
same-tree comparison, and a post-pin repository run. The version string is a
compatibility check, not revision identity. `scripts/llzk/lib.sh` therefore
does not change, and the new WTNS/R1CS output remains outside this frontend's
claims.

## D033 — Bound every u64 value and refuse an unproved `val`

**Status:** accepted

**Date:** 2026-08-21

**Enacted by:** S26

`Witgen.U64Expr` computes modulo `2^64`; LLZK's felt operations read canonical
representatives and return a field element modulo `p`. Neither “the field holds
a u64” nor “the field is at most 64 bits” is a sufficient lowering rule. On a
wide field, `U64Expr.val` truncates its field operand. On a narrow field, an
intermediate u64 value can exceed `p`; once LLZK reduces that intermediate, a
later bitwise, shift, division, or modulo operation sees a different integer.

S26 therefore admits a u64 expression only when a checked analysis proves an
exclusive upper bound at most the configured prime. Every emitted felt
representative is then the same integer as the corresponding u64 value;
addition, multiplication, and left shift also cannot have wrapped modulo
`2^64` before reaching that bound. The semantic theorem requires the backend's
existing `CanonicalRepr` certificate: its `val_add`/`val_mul` laws are what make
bounded u64 addition/multiplication agree with felt arithmetic. `FiniteField`
alone would make that claim false for binary fields.

There is intentionally no special “the root may reduce once” exception.
`FiniteField.fromNat` is specified as the inverse of `val` only for naturals
below `FiniteField.size`; above it the class imposes no reduction law. The
concrete `F p` instance uses `Nat.cast`, but this backend's entry points are
generic over every `FiniteField` with `CanonicalRepr`, and `CanonicalRepr` pins
`val` without constraining `fromNat` outside its specified range. Claiming a
root reduction would therefore make the lowering theorem false for a legal
instance. A future, separately scoped range annotation or stronger class may
relax this refusal; prose knowledge that today's corpus uses `F p` may not.

The analysis is total and fail-closed: unsupported constructors and an
unprovable bound return a diagnostic, never a guessed width. The theorem owned
by `WitnessCheck.lean` states that every expression admitted by the independent
source reader evaluates to the same field element as Clean's witness IR. A
separate bound theorem states that every successful nested analysis evaluates
below the bound it reports. These are the executable form of the policy; the
prose is not a substitute for either theorem. `eval_bitsOf` separately proves
each directly lowered decomposition cell equals Clean's `VExpr.bitsOf` value.

The `val` bridge has one deliberately narrower rule. A `.val x` leaf is admitted
only when the configured prime is at most `2^64`. `Analyze.checkField` already
establishes that this prime is `FiniteField.size F`, and `FiniteField.val_lt`
then proves the representative is below `2^64`, so `UInt64.ofNat` is exact. On
bn254 and grumpkin every `.val` leaf is refused. S26 does not infer bounds from a
`FormalCircuit`'s assumptions or constraints, and no range annotation exists in
the witness IR, so accepting a wide-field `.val` would turn an unstated caller
promise into the same kind of silent semantic gap D019 closed. Pure constants
and operations not rooted in `.val` remain eligible on wide fields when their
own bounds pass.

This exposes a contradiction in S26's original acceptance text. The existing
XOR gadgets apply `lxor` directly to `.val` leaves and carry their boolean/byte
bounds in `FormalCircuit.Assumptions` and constraints, not in the witness IR.
The frontend compiles only the witness IR and cannot recover those bounds. It
can prove arbitrary `land` safe (`x &&& y ≤ x`), but it must continue to refuse
an `lxor` or `lor` whose syntactic upper bound can reach `p`. Consequently S26
cannot honestly make every current XOR diagnostic disappear without adding a
range contract to the source language or performing a new constraint analysis;
both exceed this packet. The measured coverage must record that refusal rather
than edit the guard to the result the packet predicted.

Division and modulo additionally require a denominator proved nonzero; S26
keeps the literal nonzero denominator rule rather than pretending an upper bound
proves positivity. Shifts require a proved amount below 64. Lean masks a u64
shift count modulo 64, while LLZK shifts by the felt representative, so any
unproved count is refused; left shift also carries the non-wrapping result bound
above. A literal shift count must also be below the field prime, so its
`felt.const` is canonical. `idx`, `localVar`, and `ite` remain refused because
loops, let-steps, and control flow are separate increments.

`VExpr.bitsOf` is not routed through `U64Expr.val`: it means the low bits of the
full `FiniteField.val` and is lowered directly with LLZK felt shift/bit
operations. It therefore does not weaken the wide-field `val` refusal.

## D034 — Preserve lookup rows as true multidimensional LLZK arrays

**Status:** accepted

**Date:** 2026-08-21

**Enacted by:** S28

The exact accepted LLZK source and Nix tools settle the target surface. A static
multi-column table is one `array.type` with dimensions `[row-count, arity]` and
a flat row-major initializer. Its query is a one-dimensional row built by
`array.new`, and `constrain.in` accepts that row because its dimensions are the
suffix of the table dimensions. Recursive nesting is not an equivalent
spelling: LLZK rejects an `array.type` whose element is another `array.type`.
The direct parse, verifier round trip, full-inlining/product pipeline, and
witness-execution probes are recorded in
`evidence/S28/llzk-multicolumn-ops.md`; witgen ignores `@constrain`, so D017 is
unchanged.

The backend IR represents an array type by an ordered dimension vector plus one
scalar element type; supported builders and render readback enforce a nonempty
dimension list. `ConstArray` retains `arity` and
`Array (Array Nat)` rows, derives its declared dimensions and flat row-major
initializer from that one structure, and never use the flattened values as the
semantic table representation. A recognized lookup retains every entry
expression in order. Arity greater than one lowers those entries to one
`array.new` row and constrains that row against the global; arity one may retain
LLZK's scalar degenerate form, while every backend comparison still represents
it as a one-element row.

G9 makes the same distinction observable. `ConstraintSet.lookups` carries
one ordered polynomial row per lookup, and `globals` carries the nested rows of
each global. The independent module reader acquires an explicit row slot for
`array.new`, validates the table and query types from their dimensions, and
compares nested rows. Splitting a row into scalar memberships, exchanging
columns, or regrouping a flat scalar bag must therefore make `agree` false even
if both sides still contain the same individual field values.

The certificate boundary is generalized at the `RawTable` level, which is
the heterogeneous row-erased form a `Lookup` actually carries. A certificate
ties the exported name and arity to that raw table and equates `RawTable.Contains`
with membership of the ordered canonical-representative row in `ExportTable.rows`.
`CertifiedTable` stores one `RawTable F`; a single `CertifiedConfig` can
hold `ByteTable.toRaw` (arity one) and `ByteXorTable.toRaw` (arity three) without
fixing its public carrier to `Table F field`. The canonical-value bridge and the
lookup/soundness chain likewise concludes membership of an emitted field
row, not a flattened scalar bag.

This does not close D012's residual identity gap. The caller can still choose
the raw table paired with an export, and must prove that each circuit lookup is
that table. It merely permits the existing named assumption to range over every
arity without weakening its certificate. S28 requires the generic chain to be
instantiated concretely for `And8`, and does so in `Test/Lookups.lean` and
`Test/Soundness.lean`. The full 65536-by-3 `ByteXor` table materializes as
196,608 canonical values; its certificate, renderer, pinned verifier,
round-trip, product pipeline, and both witness backends complete within the
recorded bounds in `evidence/S28/scale.md`. Implementation and scale acceptance
are complete.

## D035 — Make XOR byte bounds executable in witness semantics

**Status:** accepted; Clean source contract enacted, frontend bounds pending

**Date:** 2026-08-22

**Enacted by:** S29

The existing Xor32 witness computes each limb as `x.val ^^^ y.val`. Its byte
bounds live in `FormalCircuit.Assumptions` and lookup constraints, neither of
which is visible to the witness program or the frontend's independent witness
reader. Teaching the backend to trust those hidden facts would invalidate
D033's theorem-or-refusal boundary.

S29 instead makes narrowing execute in the source witness IR. Each Xor32 limb
will compute:

```text
(x.val % 256) ^^^ (y.val % 256)
```

Under `U32.Normalized`, both modulo operations are identities, so Xor32's
existing semantic `Spec` is unchanged. Outside the assumptions, the narrowing
still executes in Clean and in emitted LLZK. This is not a trusted range
annotation and does not infer a witness fact from constraints.

The generic bound analysis gains two rules. For a nonzero literal divisor `d`,
if the recursively analyzed numerator has exclusive bound `ba`, modulo reports
`min ba d`; the proof uses both `a % d ≤ a` and `a % d < d`. The existing
operational checks still require `d < prime`, and emitter and independent reader
must recursively admit the numerator. A small final bound may never hide an
unsafe intermediate, an unsupported constructor, u64 wrap, or an earlier felt
reduction.

For `lor` and `lxor`, recursively obtained bounds `ba` and `bb` determine the
common envelope

```text
2 ^ Nat.clog 2 (max ba bb).
```

The rule is admitted only when that envelope is at most `2^64`; the existing
root check additionally requires it at most the configured field prime.
`Nat.le_pow_clog`, followed by `Nat.or_lt_two_pow` or
`Nat.xor_lt_two_pow`, supplies the source-side range theorem. Recursive child
admission remains mandatory. Consequently `% 256` operands yield the exact
exclusive bound 256, while a raw Babybear `.val ^^^ .val` obtains the next
power-of-two envelope above the prime and remains refused.

D033's `.val` rule is unchanged. A `.val` leaf is still admitted only when the
field size is at most `2^64`; modulo's small result bound does not make a
wide-field numerator faithful. Although `% 256` happens to commute with u64
truncation, arbitrary `% d` does not, and S29 does not add the separate theorem
needed to exploit that special case. Xor32 promotion is therefore scoped to the
accepted Babybear configuration, not claimed for bn254 or grumpkin.

The source change is Clean core, not a backend exception. It will live in a
Clean-only commit based exactly on upstream `0e53b9f2`. The frontend adopts
that commit by a reviewed merge which, in the same commit, advances the accepted
Clean overlay pin and changes G0 to compare core byte identity from the overlay.
G0 must retain the upstream base separately and verify that the overlay descends
from it and changes only the reviewed Clean path. Xor32 must not be added to a
backend allowlist.

Required red controls include the existing bare XOR; separate modulo-wrapped
additions whose intermediate exceeds the field prime and whose intermediate
exceeds `2^64`; `.idx % 256`; dynamic, zero, prime-sized, and oversized modulo
divisors; wide-field `.val % 3` and `.val % 256`; an XOR/OR envelope above the
field prime; and G9 substitutions of OR for XOR, a wrong operand, and a wrong
modulo divisor. Numeric guards pin the envelope around 255, 256, 257, `2^63`,
and `2^64`. Xor32 corpus vectors must include per-limb out-of-assumption values
which discriminate executable narrowing from the old raw XOR.
