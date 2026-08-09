import Clean.Backend.LLZK.Poly
import Clean.Backend.LLZK.Circuit
import Clean.Backend.LLZK.Print

/-!
# Gate G9: does the emitted `@constrain` say what Clean's circuit says?

This is the gap R2 demonstrated rather than argued: an `Addition8FullCarry`
module with a **completely empty `@constrain`** passes G3, G4, G5, G6, G7 and
G10 on every input vector. `llzk-witgen` executes `compute()` and ignores
`constrain()`, `llzk-opt` only type-checks it, and the goldens were generated
from the emitter, so they detect drift rather than error. Nothing looked at the
constraints.

This module looks at them, by reading both sides into the same normal form:

* `ConstraintSet.ofSource` reads the **Clean** circuit — the `.assert` and
  `.lookup` operations of `Source.operations`, plus the output expressions.
* `ConstraintSet.ofModule` reads the **emitted module** — the statements of
  `@constrain`, as data, knowing nothing about the circuit they came from.

The two meet only at `Poly`. Neither reader can see the other's input, so an
emitted constraint that is missing, duplicated, or carries a wrong coefficient
makes the comparison fail.

**The comparison is a precondition of emission** (D018). `compileSource'` runs it
and refuses to return a module that fails, and `compile`/`emit` — the public
entry points, which is why they are at the bottom of this file rather than in
`Circuit.lean` — go through it. So this is not a property of the corpus: no
module leaves this backend without it. `Test/Constraints.lean` additionally pins
that the comparison can go *red*, which is what makes the green worth anything.

## What this establishes, and what it assumes

`ofSource_eqs_iff` proves that the Clean-side polynomials hold at an assignment
exactly when the *assertion* half of `ConstraintsHoldFlat` does, together with
the output definitions D008 adds. So when the two polynomial sets agree, the
emitted `constrain.eq`s are satisfied by exactly the assignments that satisfy
Clean's assertions — *given* that `ofModule` reads the emitted IR the way LLZK
does.

The **lookup half of `ConstraintsHoldFlat` has no such theorem here.**
`lookups_perm_of_compileSource'` is a statement about `Poly` data: the emitted
`constrain.in`s name the tables Clean's `.lookup`s named and query the same
polynomials. Turning that into `Lookup.Contains` needs
`TableCert.certified_membership`, which needs a certificate for the table the
circuit actually uses — and `RawTable` has erased which `Table` that is. So the
composed end-to-end statement does not exist, and R4a-6 was right to say the
docstring implied it did.

That last clause is an assumption, and it is deliberately a small and inspectable
one: `felt.add` is `+`, `felt.mul` is `*`, `felt.const n` is `fromNat n`,
`struct.readm` reads the cell of that name, `constrain.eq a, b` is `a = b`, and
`constrain.in t, v` is membership. It is the same *kind* of assumption as D011,
and it is recorded as D017. Three things narrow it further: `ofModule` is
fail-closed on every statement form it does not model; it re-derives the
component's shape (input count, witness count, output count) from the module
alone, so a layout disagreement is a mismatch rather than a shared blind spot;
and since A4 it checks every `Ty` against the configured field, so a module
emitted in the wrong field is a mismatch here rather than only in
`Analyze.checkField` (`GAPS.md` §6).

**Lookups.** The comparison checks that each `constrain.in` names the table
Clean's `.lookup` named and queries the same polynomial. That the *rows* are the
table's rows is a separate obligation, `ExportTable.Certifies`, and
`Clean/Backend/LLZK/TableCert.lean` discharges it for every table this backend
can be given — generically for anything derived from a `StaticTable`, and
specifically for `Gadgets.ByteTable`, which cannot be. What the compiler does not
do is *demand* the certificate: `Config.tables` takes bare `ExportTable`s, and
tying a certificate to a lookup would need the `Table` that `RawTable` erased.
For the corpus the obligation is discharged and the build enforces it, because
`Examples.byteTable_certified` holds by `rfl` and breaks if the rows change.
-/

namespace LLZK

variable {F : Type} [Field F] [DecidableEq F]

/-! ## Clean's constraints as polynomials -/

/-- Read a Clean circuit expression as a polynomial. Total: `Expression` has
exactly these four constructors. -/
def Expression.toPoly : Expression F → Poly F
  | .var v => Poly.var (.circuit v.index)
  | .const c => Poly.const c
  | .add a b => Poly.add (toPoly a) (toPoly b)
  | .mul a b => Poly.mul (toPoly a) (toPoly b)

/-- The assignment a comparison is stated over: circuit variables take their
values from Clean's environment, and the emitter's `@out{j}` members from a
separate function, because they are cells Clean does not have (D008). -/
def assign (env : Environment F) (outs : Nat → F) : PVar → F
  | .circuit i => env.get i
  | .output j => outs j

/-- Reading a Clean expression as a polynomial preserves its meaning. -/
theorem Expression.eval_toPoly (env : Environment F) (outs : Nat → F) (e : Expression F) :
    Poly.eval (assign env outs) (toPoly e) = e.eval env := by
  induction e with
  | var v => simp [toPoly, assign, Expression.eval]
  | const c => simp [toPoly, Expression.eval]
  | add a b iha ihb => simp [toPoly, Expression.eval, Poly.eval_add, iha, ihb]
  | mul a b iha ihb => simp [toPoly, Expression.eval, Poly.eval_mul, iha, ihb]

/-- A constraint system in normal form. -/
structure ConstraintSet (F : Type) where
  /-- How many field elements the component takes.

  Compared, not merely used: R4a-4 showed that a module built for a 1-input
  circuit matched a 4-input source, because the module-side count was only ever
  an *offset* inside `memberVar` and the Clean side never read
  `Source.inputSize` at all. That is precisely the D014 blind spot this reader
  claims to avoid. -/
  inputs : Nat
  /-- Each polynomial must evaluate to zero. -/
  eqs : List (Poly F)
  /-- Each queried polynomial must be a row of the table of that name. -/
  lookups : List (String × Poly F)
  /-- The lookup tables the module materializes, name and values.

  **This does not check that the rows are the Clean table's rows.** Both sides
  derive from `cfg.tables`, so on the path `compile` takes it is a tautology —
  R5's X1, and the reason an earlier version of this docstring, which claimed it
  closed R4's one-row-`@Bytes` finding, was withdrawn. `Test/Constraints.lean`
  pins the tautology rather than describing it.

  What it does establish is that the emitter did not drop, rename or reorder a
  table relative to the operations that look into it. Tying the rows to the Clean
  table is `ExportTable.Certifies`, demanded by `CertifiedConfig` — which the
  public entry points take, so the proof reaches the compiler rather than being
  erased at a wrapper (S24) — and confined by G12. -/
  globals : List (String × Array Nat)
deriving Repr

namespace ConstraintSet

/-- The polynomials for the output members: `@out{j} - ⟦output j⟧`. These are the
emitter's own constraints (D008), not Clean's, so they are kept separate in the
correctness statement below. -/
def outputEqs (outputs : List (Expression F)) : List (Poly F) :=
  outputs.zipIdx.map fun (e, j) => Poly.sub (Poly.var (.output j)) (Expression.toPoly e)

/-- Read the Clean circuit.

`FlatOperation.constraints` and `FlatOperation.lookups` are Clean's own
extractors, and they are the ones `constraintsHoldFlat_iff_forall_mem` is stated
over — so this reader is not a re-reading of the operation list that could
disagree with Clean about which operations are constraints. -/
def ofSource (cfg : Config) (src : Source F) : ConstraintSet F where
  inputs := src.inputSize
  eqs :=
    (FlatOperation.constraints src.operations).map Expression.toPoly
    ++ outputEqs src.outputs.toList
  lookups :=
    (FlatOperation.lookups src.operations).flatMap
      fun l => (l.entry.toArray.map fun e => (l.table.name, Expression.toPoly e)).toList
  -- The tables the circuit actually looks into, found by walking the operations
  -- rather than by asking the emitter which ones it kept.
  --
  -- **This conjunct does not check that the rows are the Clean table's rows,**
  -- and an earlier docstring implied it did. Both sides derive from
  -- `cfg.tables`: here directly, and in the module via `recognize` and `lower`
  -- with the same filter. On the only path that exists it is a tautology, which
  -- is R5's X1. What it does catch is the emitter dropping, renaming or
  -- reordering a table relative to the operations that look into it — a real
  -- failure mode, and the whole of what it establishes.
  --
  -- Tying the rows to the Clean table is `ExportTable.Certifies`
  -- (`Certificate.lean`), which `CertifiedConfig` demands of every table that
  -- reaches a public entry point; G12 keeps every other supplier out of
  -- non-test code.
  globals :=
    (cfg.tables.filter fun table =>
      (FlatOperation.lookups src.operations).any (·.table.name = table.name)).toList.map
        fun table => (table.name, table.rows.flatten)

/-- **The Clean side is exactly `ConstraintsHoldFlat`, plus the output
definitions.**

The left-hand side is what the polynomial comparison checks; the right-hand side
is the assertion half of Clean's own semantics of the circuit — `constraints`,
not `lookups`; see the module docstring for why the lookup half has no
counterpart. So once `ofModule` agrees with
`ofSource`, the emitted `constrain.eq`s are satisfied by exactly the assignments
that satisfy Clean's assertions — with the output members pinned to the output
expressions, which is what D008 says they are for and what A4 argued informally. -/
theorem ofSource_eqs_iff (cfg : Config) (src : Source F) (env : Environment F) (outs : Nat → F) :
    (∀ p ∈ (ofSource cfg src).eqs, Poly.eval (assign env outs) p = 0)
      ↔ (∀ e ∈ FlatOperation.constraints src.operations, e.eval env = 0)
        ∧ (∀ e j, (e, j) ∈ src.outputs.toList.zipIdx → outs j = e.eval env) := by
  simp only [ofSource, List.forall_mem_append, List.forall_mem_map, outputEqs, Prod.forall]
  constructor
  · rintro ⟨hasserts, houts⟩
    refine ⟨fun e he => ?_, fun e j hj => ?_⟩
    · have := hasserts e he
      rwa [Expression.eval_toPoly] at this
    · have := houts e j hj
      rw [Poly.eval_sub, Poly.eval_var, Expression.eval_toPoly, sub_eq_zero] at this
      simpa [assign] using this
  · rintro ⟨hasserts, houts⟩
    refine ⟨fun e he => ?_, fun e j hj => ?_⟩
    · rw [Expression.eval_toPoly]; exact hasserts e he
    · rw [Poly.eval_sub, Poly.eval_var, Expression.eval_toPoly, sub_eq_zero]
      simpa [assign] using houts e j hj

end ConstraintSet

/-! ## The emitted module's constraints as polynomials

The reader below knows nothing about `Recognized` or about the circuit that
produced the module. It walks the `@constrain` function as data. Everything it
cannot model is `none`, so a construct outside the modelled subset is a red gate,
never a silently ignored statement. -/

/-- What an SSA name in `@constrain` can hold. -/
private inductive Slot (F : Type) where
  | poly (p : Poly F)
  | table (name : String)
  /-- `%self`. Only legal as the first operand of a member read. -/
  | self

variable [FiniteField F]

namespace ConstraintSet

/-- The cell a member name denotes, given the component's shape.

`declared` is the set of member names the struct actually has. Without it the
reader accepted a `struct.readm %self[@w0]` in a component whose only member is
`@junk` (R4a-5) — the same class of hole R3-02 fixed for `global.read` and left
open for members. -/
private def memberVar (inputSize numWitnesses numOutputs : Nat) (declared : Array String)
    (name : String) : Option PVar := do
  guard (declared.contains name)
  match (List.range numWitnesses).find? (fun k => witnessMember k = name) with
  | some k => some (.circuit (inputSize + k))
  | none =>
    match (List.range numOutputs).find? (fun j => outputMember j = name) with
    | some j => some (.output j)
    | none => none

private structure Reader (F : Type) where
  slots : Array (Slot F)
  eqs : List (Poly F)
  lookups : List (String × Poly F)

private def Reader.get (r : Reader F) (v : Value) : Option (Slot F) := r.slots[v.index]?

private def Reader.poly (r : Reader F) (v : Value) : Option (Poly F) :=
  match r.get v with
  | some (.poly p) => some p
  | _ => none

/-- Bind the value a statement defines. Fails unless the statement's destination
is the next SSA index, which also checks that the emitted numbering is exactly
sequential. -/
private def Reader.define (r : Reader F) (v : Value) (s : Slot F) : Option (Reader F) :=
  if v.index = r.slots.size then some { r with slots := r.slots.push s } else none

/-- Interpret one statement of `@constrain`.

`globals` is the module's own `global.def`s, so that a `global.read` of a name no
`global.def` provides is a mismatch here and not only in `llzk-opt`.

**Every type is checked against `fieldTy`** (A4, `GAPS.md` §6). Until then neither
reader looked at a `Ty` at all, so a babybear circuit emitted entirely as
`!felt.type<"bn254">` passed both halves of G9; what caught it was
`Analyze.checkField`'s registry membership, which is a different mechanism in a
different file, while G9's own summary reported both halves green. `llzk-opt`
would also reject such a module, but the gap was in what G9 itself licensed.

An array type is checked *exactly*, against the global it reads: element type and
length both, so a `global.read @Bytes : !array.type<255 x …>` is a mismatch rather
than something only the verifier notices. -/
private def step (fieldTy : Ty) (inputSize numWitnesses numOutputs : Nat)
    (declared : Array String) (globals : Array ConstArray)
    (r : Reader F) : Stmt → Option (Reader F)
  | .feltConst dst value ty => do
    guard (ty = fieldTy)
    r.define dst (.poly (Poly.const (FiniteField.fromNat value)))
  | .feltBin dst op lhs rhs ty => do
    guard (ty = fieldTy)
    let a ← r.poly lhs
    let b ← r.poly rhs
    let combined ← match op with
      | .add => some (Poly.add a b)
      | .mul => some (Poly.mul a b)
      | .uintdiv | .umod => none
    r.define dst (.poly combined)
  | .readMember dst self member memberTy => do
    guard (memberTy = fieldTy)
    let .self ← r.get self | none
    let cell ← memberVar inputSize numWitnesses numOutputs declared member
    r.define dst (.poly (Poly.var cell))
  | .globalRead dst name ty => do
    let some g := globals.find? (·.name = name) | none
    guard (ty = Ty.array g.values.size fieldTy)
    r.define dst (.table name)
  | .constrainEq lhs rhs ty => do
    guard (ty = fieldTy)
    let a ← r.poly lhs
    let b ← r.poly rhs
    return { r with eqs := r.eqs ++ [Poly.sub a b] }
  | .constrainIn array arrayTy element elementTy => do
    guard (elementTy = fieldTy)
    let .table name ← r.get array | none
    let some g := globals.find? (·.name = name) | none
    guard (arrayTy = Ty.array g.values.size fieldTy)
    let value ← r.poly element
    return { r with lookups := r.lookups ++ [(name, value)] }
  -- `struct.new` and `struct.writem` belong to `@compute`. Reaching one here
  -- means the module is not the shape this reader models.
  | .structNew _ | .writeMember _ _ _ _ => none

/-- Read the emitted module's `@constrain`.

The component's shape is re-derived from the module — the parameter count, the
`{signal}` members and the `{llzk.pub}` members — rather than taken from the
circuit, so a layout that disagrees with Clean's is a mismatch rather than a
blind spot shared by both sides (D014's known weakness, avoided here). -/
def ofModule (fieldTy : Ty) (m : Module) : Option (ConstraintSet F) := do
  let numWitnesses := (m.root.members.filter (·.visibility = .signal)).size
  let numOutputs := (m.root.members.filter (·.visibility = .pub)).size
  let params := m.root.constrain.params
  let some self := params[0]? | none
  guard (self.ty = rootTy)
  let inputSize := params.size - 1
  let slots : Array (Slot F) :=
    #[Slot.self] ++ (Array.range inputSize).map fun i => Slot.poly (Poly.var (.circuit i))
  -- The parameters must be `%self` and then one felt each, numbered `%v0`
  -- upwards in order, or the indices the body reads do not mean what this reader
  -- assumes about them. Since A4 the felt is *the* felt, not any felt.
  guard (params.zipIdx.all fun (p, i) => p.value.index = i)
  guard ((params.extract 1 params.size).all fun p => p.ty = fieldTy)
  -- The component's state and its constant arrays, likewise. A member or a
  -- global in another field is a mismatch here rather than only in `llzk-opt`.
  guard (m.root.members.all fun mem => mem.ty = fieldTy)
  guard (m.globals.all fun g => g.elemTy = fieldTy)
  let declared := m.root.members.map (·.name)
  let mut reader : Reader F := { slots, eqs := [], lookups := [] }
  for stmt in m.root.constrain.body do
    let some next := step fieldTy inputSize numWitnesses numOutputs declared m.globals reader stmt
      | none
    reader := next
  return { inputs := inputSize, eqs := reader.eqs, lookups := reader.lookups
           globals := (m.globals.map fun g => (g.name, g.values)).toList }

/-! ## The comparison -/

/-- Whether the emitted module's constraint system is the same as the Clean
circuit's, up to the order of the constraints.

Order is deliberately not compared: constraints are a conjunction, and the
emitter groups them lookups-first (A6). Multiplicity *is* compared — `isPerm`,
not set equality — so a dropped or duplicated constraint is a mismatch. -/
def agree (cfg : Config) (src : Source F) (m : Module) : Bool :=
  match ofModule (F := F) (Ty.felt cfg.field.name) m with
  | none => false
  | some emitted =>
    let clean := ofSource cfg src
    emitted.inputs == clean.inputs
      && emitted.globals == clean.globals
      && emitted.eqs.isPerm clean.eqs && emitted.lookups.isPerm clean.lookups

/-- The check, run through the whole compilation rather than on a module handed
in — so what is compared is what the emitter actually produces. -/
def agreeCompiled [CanonicalRepr F] (cfg : Config) (src : Source F) : Bool :=
  match compileSource cfg src with
  | .error _ => false
  | .ok m => agree cfg src m

/-! ## Emission is verified, not merely checked

`agree` is decidable, so the emitter can run it on every circuit it compiles and
refuse to hand back a module that fails. That is what `compileSource'` below
does: **no module leaves a supported entry point — `compile`, `emit`,
`emitSource` in `WitnessCheck.lean` — without having been compared against its
Clean source.** Not "no module leaves this backend": `compileSource`,
`compileSource'` itself and `lowerRecognized` are public Lean defs that return
un- or half-compared modules — the six `Square_*` registry entries come through
the last of them with `constraintsAgree = none` — and what confines them to
this file, `Circuit.lean`, `WitnessCheck.lean`, `Corpus.lean` and `Test/` is
G12, a gate over the source rather than the type system. An earlier version of
this paragraph claimed the stronger sentence, and R7-13 found the same file
contradicting it two sections later.

This is translation validation rather than a verified translator. It is weaker
than a preservation theorem about `lower` in one way — it says nothing about
*why* the lowering is right, and a bug would surface as a refusal to compile
rather than as a compile-time impossibility. It is stronger in the way that
matters here: it holds for every circuit, not for the five in the corpus, and it
needed no simulation argument over the `BuilderM` state monad.

What remains outside it is D017's reading of the emitted IR, and D012's lookup
rows — and the latter is discharged for every table in use by
`Clean/Backend/LLZK/TableCert.lean`. -/

/-- What the emitter reports when its own output fails the comparison. Reaching
this is a bug in the lowering, not in the circuit, which is why the message says
so. -/
def mismatch : Diagnostic where
  context := "constraints"
  message := "the emitted @constrain is not the same constraint system as the circuit's \
              (gate G9). This is a defect in the backend, not in the circuit: please report \
              it with the circuit that triggered it. See Clean/Backend/LLZK/Constraints.lean"

/-- Compile a flattened circuit, and verify that what came out carries the
circuit's constraint system before returning it. -/
def compileSource' [CanonicalRepr F] (cfg : Config) (src : Source F) :
    Except (Array Diagnostic) Module :=
  match compileSource cfg src with
  | .error diagnostics => .error diagnostics
  | .ok m => if agree cfg src m then .ok m else .error #[mismatch]

/-- **Every module this backend emits carries its circuit's constraint system.**

Not "every module in the corpus" — the comparison is a precondition of emission,
so this is a theorem about all circuits. -/
theorem agree_of_compileSource' [CanonicalRepr F] {cfg : Config} {src : Source F} {m : Module}
    (h : compileSource' cfg src = .ok m) : agree cfg src m = true := by
  unfold compileSource' at h
  split at h
  · exact absurd h (by simp)
  · split at h
    · rename_i ha
      simp only [Except.ok.injEq] at h
      exact h ▸ ha
    · exact absurd h (by simp)

/-- **The emitted equalities are Clean's constraints, semantically.**

`agree_of_compileSource'` says the two polynomial sets match as data; this says
what that means. For any module this backend emits, the polynomials read out of
its `@constrain` vanish at an assignment exactly when Clean's
`ConstraintsHoldFlat` holds there and each `@out{j}` carries its output
expression — the definitional extension D008 adds, and which A4 previously argued
informally.

Order is irrelevant on both sides because the constraints are a conjunction, and
that is why a permutation suffices. -/
theorem eqs_iff_of_compileSource' [CanonicalRepr F] {cfg : Config} {src : Source F} {m : Module}
    {C : ConstraintSet F} (h : compileSource' cfg src = .ok m)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (env : Environment F) (outs : Nat → F) :
    (∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
      ↔ (∀ e ∈ FlatOperation.constraints src.operations, e.eval env = 0)
        ∧ (∀ e j, (e, j) ∈ src.outputs.toList.zipIdx → outs j = e.eval env) := by
  have ha := agree_of_compileSource' h
  simp only [agree, hm, Bool.and_eq_true] at ha
  have hperm : C.eqs.Perm (ofSource cfg src).eqs := List.isPerm_iff.mp ha.1.2
  rw [← ofSource_eqs_iff cfg src env outs]
  exact ⟨fun hh p hp => hh p (hperm.mem_iff.mpr hp),
         fun hh p hp => hh p (hperm.mem_iff.mp hp)⟩

/-- **The emitted lookups are Clean's lookups.**

Each `constrain.in` the module emits names the table Clean's `.lookup` named and
queries the same polynomial, with the same multiplicity. What that *means* — that
membership in the emitted array is Clean's `Contains` — is
`TableCert.certified_membership`, and needs the table certified. -/
theorem lookups_perm_of_compileSource' [CanonicalRepr F] {cfg : Config} {src : Source F}
    {m : Module} {C : ConstraintSet F} (h : compileSource' cfg src = .ok m)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C) :
    C.lookups.Perm (ofSource cfg src).lookups := by
  have ha := agree_of_compileSource' h
  simp only [agree, hm, Bool.and_eq_true] at ha
  exact List.isPerm_iff.mp ha.2

end ConstraintSet

/-! `compile` and `emit`, the public entry points, are **not** here either: they
are in `Clean/Backend/LLZK/WitnessCheck.lean`, which adds the witness half of G9
on top of `compileSource'`. Both halves are preconditions of emission (D018). -/

end LLZK
