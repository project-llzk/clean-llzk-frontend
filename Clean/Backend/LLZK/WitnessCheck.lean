import Clean.Backend.LLZK.Constraints

/-!
# The witness side of G9: does the emitted `@compute` compute what Clean does?

`Constraints.lean` does this for `@constrain`. This is the other half, and until
S19 it was the last part of the pipeline with no check of its own: `@compute` was
covered by G5–G7 — the two `llzk-witgen` backends agreeing with Clean's
interpreter on 27 input vectors — and by nothing else. Twenty-seven vectors is
evidence, not a statement about all inputs.

The shape is the same as the constraint side, and so are its limits:

* `WExpr.ofSource` reads the **Clean** circuit's witness programs and output
  expressions, and `eval_ofWitgen` proves that reading preserves
  `Witgen.FExpr.eval` — Clean's own semantics.
* `WExpr.ofModule` reads the **emitted** `@compute` as data.
* The two are compared, and the comparison is a precondition of emission (D018),
  so it holds for every circuit rather than for the corpus.

## Why a tree and not a polynomial

`@constrain` is polynomial, so a normal form absorbs the difference between
`x*y` and `y*x`. `@compute` is not: `felt.umod` and `felt.uintdiv` are the two
non-native operations Stage 1 emits, and no polynomial normal form contains them.
The comparison is therefore syntactic on trees, which is sound but stricter — two
computations that are equal but differently shaped would be reported as a
mismatch. That is fail-closed, and in practice the shapes match because both
readers are structural over the same source.

## Where the LLZK reading enters

`WExpr.eval`'s `umod` case *is* the assumption that `felt.umod a b` denotes
`fromNat (val a % val b)`, and `uintdiv` likewise. That is the D011/D017 reading,
and `eval_ofWitgen` proves Clean's `ofNat (mod (val x) (const c))` denotes the
same thing — so the two sides of D011's argument are now connected by a theorem
rather than by prose. `CanonicalRepr` (D019) is what makes `val` the
representative that reading refers to.

## What this does not do

It compares the *expressions*, cell by cell. Lifting that to
"the emitted `@compute` produces the vector `FlatOperation.dynamicWitnesses`
produces" additionally needs the block-prefix argument R2-03 is about — which
`Analyze` now enforces rather than proves. G5–G7 remain the evidence for the
whole-vector statement.
-/

namespace LLZK

/-- The comparison language for `@compute`.

`cell i` is Clean circuit variable `i`: an input when `i < inputSize`, otherwise
witness cell `i - inputSize`. Divisors are literals, for the reason D011 gives. -/
inductive WExpr where
  | cell (i : Nat)
  /-- A felt constant, as its canonical representative. -/
  | const (n : Nat)
  | add (a b : WExpr)
  | mul (a b : WExpr)
  | uintdiv (a : WExpr) (divisor : Nat)
  | umod (a : WExpr) (divisor : Nat)
deriving DecidableEq, Repr, Inhabited

namespace WExpr

variable {F : Type} [FiniteField F]

/-- The meaning of a compute expression.

The `uintdiv`/`umod` cases are the reading of `felt.uintdiv`/`felt.umod`
recorded in D017: the operands are interpreted as their canonical
representatives, the operation is on naturals, and the result re-enters the
field. -/
def eval (σ : Nat → F) : WExpr → F
  | .cell i => σ i
  | .const n => FiniteField.fromNat n
  | .add a b => eval σ a + eval σ b
  | .mul a b => eval σ a * eval σ b
  | .uintdiv a d => FiniteField.fromNat (FiniteField.val (eval σ a) / d)
  | .umod a d => FiniteField.fromNat (FiniteField.val (eval σ a) % d)

/-! ## Reading the Clean circuit

Deliberately *not* `Witness.ofFExpr`. That is the emitter's recognizer; using it
here would make the comparison a check of the emitter against itself. These are a
separate traversal, and `eval_ofWitgen` below proves they mean what Clean means —
which is the property `ofFExpr` has only by inspection. -/

/-- Read an embedded circuit expression. Total. -/
def ofExpression : Expression F → WExpr
  | .var v => .cell v.index
  | .const c => .const (FiniteField.val c)
  | .add a b => .add (ofExpression a) (ofExpression b)
  | .mul a b => .mul (ofExpression a) (ofExpression b)

/-- Rewrite every variable reference through `f`. -/
def rename (f : Nat → Nat) : WExpr → WExpr
  | .cell i => .cell (f i)
  | .const n => .const n
  | .add a b => .add (rename f a) (rename f b)
  | .mul a b => .mul (rename f a) (rename f b)
  | .uintdiv a d => .uintdiv (rename f a) d
  | .umod a d => .umod (rename f a) d

/-- Evaluation depends on the assignment only pointwise. -/
theorem eval_congr {σ τ : Nat → F} (h : ∀ i, σ i = τ i) (w : WExpr) :
    eval σ w = eval τ w := by
  induction w with
  | cell i => exact h i
  | const n => rfl
  | add a b iha ihb => simp [eval, iha, ihb]
  | mul a b iha ihb => simp [eval, iha, ihb]
  | uintdiv a d ih => simp [eval, ih]
  | umod a d ih => simp [eval, ih]

/-- Renaming commutes with evaluation.

With `eval_congr`, this is what makes canonicalising copies in
`WitnessSet.ofSource` meaning-preserving: `canon` sends a variable only to one
the witness program defines it *equal* to, so `σ ∘ canon` and `σ` agree on every
assignment the circuit can produce, and the renamed reading evaluates to the
same field element as the original. -/
theorem eval_rename (σ : Nat → F) (f : Nat → Nat) (w : WExpr) :
    eval σ (w.rename f) = eval (σ ∘ f) w := by
  induction w with
  | cell i => rfl
  | const n => rfl
  | add a b iha ihb => simp [eval, rename, iha, ihb]
  | mul a b iha ihb => simp [eval, rename, iha, ihb]
  | uintdiv a d ih => simp [eval, rename, ih]
  | umod a d ih => simp [eval, rename, ih]

/-- Read a field-sorted witness expression, or fail on anything outside the
Stage-1 subset. -/
def ofWitgen : Witgen.FExpr F → Option WExpr
  | .expr e => some (ofExpression e)
  | .const c => some (.const (FiniteField.val c))
  | .add a b => (ofWitgen a).bind fun wa => (ofWitgen b).map (WExpr.add wa)
  | .mul a b => (ofWitgen a).bind fun wa => (ofWitgen b).map (WExpr.mul wa)
  | .ofNat (.mod (.val x) (.const c)) => (ofWitgen x).map (WExpr.umod · c)
  | .ofNat (.div (.val x) (.const c)) => (ofWitgen x).map (WExpr.uintdiv · c)
  | _ => none

/-! ## The readings mean what Clean means -/

/-- Reading an embedded circuit expression preserves its meaning. -/
theorem eval_ofExpression (σ : Nat → F) (env : Environment F) (hσ : ∀ i, σ i = env.get i)
    (e : Expression F) : eval σ (ofExpression e) = e.eval env := by
  induction e with
  | var v => simp [eval, ofExpression, Expression.eval, hσ]
  | const c => simp [eval, ofExpression, Expression.eval, FiniteField.fromNat_val]
  | add a b iha ihb => simp [eval, ofExpression, Expression.eval, iha, ihb]
  | mul a b iha ihb => simp [eval, ofExpression, Expression.eval, iha, ihb]

/-- **Reading a Clean witness expression preserves its meaning.**

This is the theorem D011 wanted and could not state: the two recognized natural
division/modulo shapes denote, in Clean, exactly what `WExpr.eval` says
`felt.umod`/`felt.uintdiv` denote. Everything else in the accepted subset is
structural. -/
theorem eval_ofWitgen (ctx : Witgen.Ctx F) (σ : Nat → F)
    (hσ : ∀ i, σ i = ctx.env.get i) :
    ∀ (e : Witgen.FExpr F) (w : WExpr), ofWitgen e = some w → eval σ w = e.eval ctx := by
  intro e
  induction e using ofWitgen.induct with
  | case1 e => intro w h; cases h; exact eval_ofExpression σ _ hσ e
  | case2 c => intro w h; cases h; simp [eval, Witgen.FExpr.eval, FiniteField.fromNat_val]
  | case3 a b iha ihb =>
    intro w h
    simp only [ofWitgen, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨wa, ha, wb, hb, rfl⟩ := h
    simp [eval, Witgen.FExpr.eval, iha wa ha, ihb wb hb]
  | case4 a b iha ihb =>
    intro w h
    simp only [ofWitgen, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨wa, ha, wb, hb, rfl⟩ := h
    simp [eval, Witgen.FExpr.eval, iha wa ha, ihb wb hb]
  | case5 x c ih =>
    intro w h
    simp only [ofWitgen, Option.map_eq_some_iff] at h
    obtain ⟨wx, hx, rfl⟩ := h
    simp [eval, Witgen.FExpr.eval, Witgen.NExpr.eval, ih wx hx]
  | case6 x c ih =>
    intro w h
    simp only [ofWitgen, Option.map_eq_some_iff] at h
    obtain ⟨wx, hx, rfl⟩ := h
    simp [eval, Witgen.FExpr.eval, Witgen.NExpr.eval, ih wx hx]
  | case7 e _ => intro w h; simp [ofWitgen] at h

end WExpr

/-- What `@compute` produces: one expression per witness cell, then one per
output field element. -/
structure WitnessSet where
  /-- How many field elements the component takes. Compared, for the reason
  `ConstraintSet.inputs` gives: without it a module built for a 1-input circuit
  matched a 4-input source (R4a-4). -/
  inputs : Nat
  cells : List WExpr
  outputs : List WExpr
deriving DecidableEq, Repr

namespace WitnessSet

variable {F : Type} [FiniteField F]

/-- Read a whole witness program: `m` expressions, or nothing. -/
private def ofProgram {m : Nat} : Witgen.WitgenIR F m → Option (List WExpr)
  | .ir [] (.lit es) => es.toList.mapM WExpr.ofWitgen
  | _ => none

/-! ### Canonicalising copies

A witness cell whose program is a bare variable — `witness x`, returning the
input unchanged — is a *copy*: circuit variable `inputSize + k` and the variable
it copies denote the same field element, always. The emitted module cannot tell
them apart, because `FieldExpr.lower` returns the existing SSA value rather than
emitting anything, so `struct.writem @w{k} = %v` writes the very value that
already stood for the original.

This is not a choice the comparison gets to make. `ofModule` reads the module and
nothing else, and `witness x; return x` and `witness x; return that cell` emit
*byte-identical* modules — the distinction is simply not present in the artifact.
So any check that accepts one must accept the other, and both sides rewrite every
copy to the variable it copies.

Accepting both is sound because the module is a correct lowering of both: a copy
cell is *defined* to hold the value it copies, so the two variables denote the
same field element under every assignment the witness generator can produce.
`eval_rename` and `eval_congr` above are the two halves of that argument; what
they are applied to — that `canon` sends a variable only to one the program
defines it equal to — is the three lines below, and is checked by inspection
rather than proved. GAPS.md records it.

R5c found the alternative the hard way: with the reader alone rebinding,
`witness x; y === x; return x` — a proved `FormalCircuit` whose emitted module is
correct — was refused and told to file a backend bug.

Only *bare* copies collapse. A cell computing `x + 0` is a fresh value with its
own SSA statement, and stays distinct. -/

/-- Read the Clean circuit's witness programs and outputs. -/
def ofSource (src : Source F) : Option WitnessSet := do
  let mut raw : List WExpr := []
  for op in src.operations do
    if let .witness _ program := op then
      raw := raw ++ (← ofProgram program)
  -- `canon` sends each circuit variable to the one it is a copy of, or to
  -- itself. Built in order, so a cell's references are always already resolved.
  let mut canon : Array Nat := Array.range src.inputSize
  let mut cells : Array WExpr := #[]
  for w in raw do
    let w := w.rename fun i => canon[i]?.getD i
    canon := canon.push (match w with | .cell j => j | _ => canon.size)
    cells := cells.push w
  return { inputs := src.inputSize, cells := cells.toList,
           outputs := src.outputs.toList.map fun e =>
             (WExpr.ofExpression e).rename fun i => canon[i]?.getD i }

/-! ## Reading the emitted `@compute`

`@compute`'s parameters are the inputs, with no `%self`; `struct.new` defines
`%self` as the first statement. A write to `@w{k}` records the cell's expression
and, in the ordinary case, rebinds the written SSA value to `cell (inputSize +
k)`: every later use of it denotes that cell, which is how the Clean side names
it. Without the rebinding the emitted side would inline earlier cells and the two
would never match.

The exception is a cell that is a bare copy — see "Canonicalising copies" above.
There the written value is one the body did not compute, and rebinding it would
rename the original for the rest of `@compute`. Because `FieldExpr.lower` returns
an existing value only in its `.var` case, and every other case emits a statement
whose slot is a `const`/`add`/`mul`/`uintdiv`/`umod`, *the slot already holding a
bare `cell` is exactly the copy case*. That is the test used below. -/

/-- What an SSA name in `@compute` can hold. -/
private inductive Slot where
  | expr (w : WExpr)
  /-- `%self`, the value `struct.new` produced. -/
  | self

private structure Reader where
  slots : Array Slot
  cells : List WExpr
  outputs : List WExpr

private def Reader.expr (r : Reader) (v : Value) : Option WExpr :=
  match r.slots[v.index]? with
  | some (.expr w) => some w
  | _ => none

private def Reader.define (r : Reader) (v : Value) (s : Slot) : Option Reader :=
  if v.index = r.slots.size then some { r with slots := r.slots.push s } else none

/-- Rebind an already-defined slot, which only a member write does. -/
private def Reader.rebind (r : Reader) (v : Value) (w : WExpr) : Option Reader :=
  if h : v.index < r.slots.size then some { r with slots := r.slots.set v.index (.expr w) h }
  else none

/-- Interpret one statement of `@compute`. -/
private def step (inputSize : Nat) (r : Reader) : Stmt → Option Reader
  | .structNew dst => r.define dst .self
  | .feltConst dst value _ => r.define dst (.expr (.const value))
  | .feltBin dst op lhs rhs _ => do
    let a ← r.expr lhs
    let b ← r.expr rhs
    match op with
    | .add => r.define dst (.expr (.add a b))
    | .mul => r.define dst (.expr (.mul a b))
    -- The divisor must be a literal, which is what `FieldExpr.lower` emits and
    -- what D011's side conditions are checked against.
    | .uintdiv => match b with
      | .const d => r.define dst (.expr (.uintdiv a d))
      | _ => none
    | .umod => match b with
      | .const d => r.define dst (.expr (.umod a d))
      | _ => none
  | .writeMember self member value _ => do
    let .self ← r.slots[self.index]? | none
    let w ← r.expr value
    if member = witnessMember r.cells.length then
      let r ← if w matches .cell _ then some r
              else r.rebind value (.cell (inputSize + r.cells.length))
      return { r with cells := r.cells ++ [w] }
    else if member = outputMember r.outputs.length then
      return { r with outputs := r.outputs ++ [w] }
    else none
  -- `struct.readm`, `global.read` and the two constraint forms belong to
  -- `@constrain`. Reaching one here means the module is not the shape this
  -- reader models.
  | .readMember .. | .globalRead .. | .constrainEq .. | .constrainIn .. => none

/-- Read the emitted module's `@compute`.

The input count comes from the parameter list, and the cell and output counts
from the order the writes appear in — so a module whose layout disagrees with
Clean's is a mismatch rather than a blind spot shared by both sides. -/
def ofModule (m : Module) : Option WitnessSet := do
  let params := m.root.compute.params
  guard (params.zipIdx.all fun (p, i) => p.value.index = i)
  guard (params.all fun p => match p.ty with | .felt _ => true | _ => false)
  let mut reader : Reader :=
    { slots := (Array.range params.size).map fun i => Slot.expr (.cell i)
      cells := [], outputs := [] }
  for stmt in m.root.compute.body do
    let some next := step params.size reader stmt | none
    reader := next
  return { inputs := params.size, cells := reader.cells, outputs := reader.outputs }

/-- Whether the emitted `@compute` computes the circuit's witnesses and outputs.

Order matters here, unlike the constraint side: cell `k` is circuit variable
`inputSize + k`, so a permutation would be a different circuit. -/
def agree (src : Source F) (m : Module) : Bool :=
  match ofModule m, ofSource src with
  | some emitted, some clean => emitted == clean
  | _, _ => false

end WitnessSet
end LLZK

/-! ## The verified entry points

Both halves of G9 are preconditions of emission (D018): `compileSource'` checks
`@constrain` against the circuit's constraints, and the step below checks
`@compute` against its witness programs. `compile` and `emit` are the only public
ways to obtain a module, and they go through both — so there is no path from a
Clean circuit to LLZK text that has not been compared against the circuit on
both sides.
-/

namespace LLZK

variable {F : Type} [FiniteField F] [DecidableEq F]

/-- What the emitter reports when its own `@compute` fails the comparison.
Reaching this is a bug in the lowering, not in the circuit. -/
private def witnessMismatch : Diagnostic where
  context := "witness"
  message := "the emitted @compute does not compute the circuit's witnesses (gate G9, witness \
              side). This is a defect in the backend, not in the circuit: please report it with \
              the circuit that triggered it. See Clean/Backend/LLZK/WitnessCheck.lean"

/-- Check a module against the circuit it claims to be — **both** halves of G9 —
and refuse it if it is not.

Factored out of `compileSourceVerified` so that the *refusal* is reachable from a
test: without a function taking the module as an argument, the error branch would
be dead code and "the check refuses a wrong module" would be an untested claim
about the one path that matters. `Test/WitnessCheck.lean` calls it with one
circuit's module and another circuit's source.

Two things this docstring used to get wrong, both found by R5c.

It said *"nothing the emitter produces can fail this"*. Something did: a bare
copy of a variable, which the witness reader misread. That claim is also what
justified never running the branch against real emitter output. The cause is
fixed — see "Canonicalising copies" — but the claim is not reinstated, because
the same sentence is what stopped anyone looking.

And it checked only the witness half while promising to refuse any module that
is not the circuit, which is exactly R2's empty-`@constrain` attack. It runs both
halves now. `compileSourceVerified` reaches it through `compileSource'`, which
has already checked the constraint half, so that half runs twice on the compile
path; it is a pure comparison of two normal forms, and paying for it is better
than a public function that means less than its name. -/
def verify [CanonicalRepr F] (cfg : Config) (src : Source F) (m : Module) :
    Except (Array Diagnostic) Module :=
  if !ConstraintSet.agree cfg src m then .error #[ConstraintSet.mismatch]
  else if !WitnessSet.agree src m then .error #[witnessMismatch]
  else .ok m

/-- Compile a flattened circuit and verify **both** halves of G9 before returning
it. -/
def compileSourceVerified [CanonicalRepr F] (cfg : Config) (src : Source F) :
    Except (Array Diagnostic) Module :=
  match ConstraintSet.compileSource' cfg src with
  | .error diagnostics => .error diagnostics
  | .ok m => verify cfg src m

/-- **Every module this backend emits computes the circuit's witnesses.** -/
theorem witnessAgree_of_compileSourceVerified [CanonicalRepr F] {cfg : Config}
    {src : Source F} {m : Module}
    (h : compileSourceVerified cfg src = .ok m) : WitnessSet.agree src m = true := by
  unfold compileSourceVerified verify at h
  split at h
  · exact absurd h (by simp)
  · split at h
    · exact absurd h (by simp)
    · split at h
      · exact absurd h (by simp)
      · rename_i hw
        simp only [Except.ok.injEq] at h
        subst h
        simpa using hw

/-- **…and carries its constraint system.** The other half, lifted through the
same entry point. -/
theorem constraintsAgree_of_compileSourceVerified [CanonicalRepr F] {cfg : Config}
    {src : Source F} {m : Module}
    (h : compileSourceVerified cfg src = .ok m) : ConstraintSet.agree cfg src m = true := by
  unfold compileSourceVerified verify at h
  split at h
  · exact absurd h (by simp)
  · rename_i m' hc
    split at h
    · exact absurd h (by simp)
    · split at h
      · exact absurd h (by simp)
      · simp only [Except.ok.injEq] at h
        exact h ▸ ConstraintSet.agree_of_compileSource' hc

/-- Compile a circuit to an LLZK module, or report every reason it cannot be.

Verified on both sides — see the two theorems above. There is no name to pass:
the component is always `@Main` (D015). -/
def compile {C : Type} [CanonicalRepr F] [Compilable C F] (cfg : Config) (c : C) :
    Except (Array Diagnostic) Module :=
  compileSourceVerified cfg (Compilable.source (F := F) c)

/-- Emit a circuit as textual LLZK, or as the diagnostics explaining why not.

The interactive form: `#eval IO.print (LLZK.emit cfg circuit)`. The artifact form
is `Clean/Backend/LLZK/EmitMain.lean`. -/
def emit {C : Type} [CanonicalRepr F] [Compilable C F] (cfg : Config) (c : C) : String :=
  renderResult (compile cfg c)

/-- The same, for a circuit already reduced to a `Source`. -/
def emitSource [CanonicalRepr F] (cfg : Config) (src : Source F) : String :=
  renderResult (compileSourceVerified cfg src)

end LLZK
