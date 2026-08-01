import Clean.Backend.LLZK.Basic
/-!
# A backend-local IR for the LLZK subset Clean emits

This is deliberately *not* a model of MLIR, of LLZK, or of VeIR. It models exactly
the fragment of textual LLZK described in `doc/llzk/ARCHITECTURE.md` §5, and
nothing else. Anything the frontend cannot express here must be rejected by the
analyzer before it reaches this module, which is what keeps the backend
fail-closed.

## What this layer rules out, and what it does not

This is the reason the lowering builds a value rather than concatenating strings.
Stated as what a lowering *cannot* do, because the previous, stronger phrasing
("a struct that is not a valid LLZK component cannot be built") was false — see
R2-04:

* **A body cannot name an SSA value nothing defines.** `Value` has a private
  constructor and `Builder.fresh` is private, so a body cannot spell one. That
  alone is not enough — `Param.value` is a public projection, so a body could
  capture a `Value` belonging to a *different* component and reference an index
  its own function never allocated (R4b-3 built exactly that, and `llzk-opt` said
  "use of undeclared SSA value name"). `Builder.assemble` therefore checks that
  every operand a body emitted is below the number of values that body allocated,
  and refuses the function otherwise.
* **A function's result cannot disagree with its signature.** `Func.result` is
  one `Option (Value × Ty)`, so the declared return type and the rendered
  `function.return` come from the same place, and a body can neither lack a
  terminator nor carry two.
* **The two functions of a component share one parameter list.** `Builder.component`
  is the only way to build a `StructDef`, and it takes a single
  `Array ParamSpec` and hands it to both. LLZK requires `@constrain`'s argument
  types, minus `%self`, to equal `@compute`'s; that now holds by construction
  rather than by both callers passing the same array.
* **A module has exactly one component, and `llzk.main` points at it.**
  `Module.root` is a single `StructDef`, and the component is always named
  `rootComponent`, so `llzk.main` cannot dangle and the root cannot be missing.

What is *not* ruled out here, and is therefore checked before this module runs:
that a global's name is a legal MLIR symbol and does not collide with the
component (`Table.diagnoseRegistry`), and that a `global.read` names a global the
module defines (the lowering reads both from the same registry entry).

Rendering lives in `Clean.Backend.LLZK.Print`; this module has no notion of
syntax.
-/

namespace LLZK

/-- The name of the component every emitted module is built around.

Fixed rather than derived from the circuit, for two independent reasons:

* `doc/llzk/ARCHITECTURE.md` §5 specifies `struct.def @Main`;
* `llzk-opt --llzk-product-program` — the entry point to the whole LLZK analysis
  pipeline — looks up a root struct named literally `Main` and ignores
  `llzk.main`. An emitted module whose component is named anything else cannot
  enter any downstream analysis. See D015.

A constant is also why no component name needs validating: it is a legal MLIR
symbol by inspection. The one thing a caller can still collide with it is a table
name, which `Table.diagnoseRegistry` checks. -/
def rootComponent : String := "Main"

/-- A type in the Stage-1 LLZK subset.

`felt` carries the LLZK field-registry name (`"babybear"`, `"bn254"`, …) rather
than a prime: the registry owns the prime, and a module that disagrees with it is
rejected by `llzk-opt`.

No `Inhabited` instance, for the reason `Value` has none: a default would render
as `!felt.type<"">`, and the point of this IR is that nothing downstream has to
re-check what the lowering built. -/
inductive Ty where
  | felt (field : String)
  | array (size : Nat) (elem : Ty)
  | struct (name : String)
deriving DecidableEq, Repr

/-- The component's own type, `!struct.type<@Main>`. -/
def rootTy : Ty := .struct rootComponent

/-- An SSA value. Opaque by construction: only the private `Builder.fresh`
allocates one, so every value a statement mentions is one some earlier statement
or parameter defined. -/
structure Value where
  private mk ::
  index : Nat
deriving DecidableEq, Repr

/-- The binary `felt` operations Stage 1 emits.

`uintdiv` and `umod` interpret their operands as canonical representatives in
`[0, p)`. They are not field operations, so a function using them must carry
`FuncAttr.allowNonNativeFieldOps`.

`felt.sub` and `felt.div` are deliberately absent. Clean's `Expression` has
neither — subtraction is `x + (p-1) * y` — so no lowering could produce them, and
carrying them meant the renderer had cases only a fixture reached (R2-08). -/
inductive FeltBinOp where
  | add
  | mul
  | uintdiv
  | umod
deriving DecidableEq, Repr

/-- Whether an operation is a field operation in LLZK's sense. A function whose
body contains a non-native operation must declare
`FuncAttr.allowNonNativeFieldOps`; `Builder.assemble` maintains that invariant. -/
def FeltBinOp.isNative : FeltBinOp → Bool
  | .add | .mul => true
  | .uintdiv | .umod => false

/-- A statement in a function body.

Terminators are deliberately absent: a `Func` carries its result separately, so
a body can neither lack a terminator nor contain two. -/
inductive Stmt where
  | feltConst (dst : Value) (value : Nat) (ty : Ty)
  | feltBin (dst : Value) (op : FeltBinOp) (lhs rhs : Value) (ty : Ty)
  | structNew (dst : Value)
  | readMember (dst : Value) (self : Value) (member : String) (memberTy : Ty)
  | writeMember (self : Value) (member : String) (value : Value) (memberTy : Ty)
  | globalRead (dst : Value) (name : String) (ty : Ty)
  | constrainEq (lhs rhs : Value) (ty : Ty)
  | constrainIn (array : Value) (arrayTy : Ty) (element : Value) (elementTy : Ty)
deriving Repr

/-- Whether a statement needs `FuncAttr.allowNonNativeFieldOps` on its function. -/
def Stmt.needsNonNativeFieldOps : Stmt → Bool
  | .feltBin _ op _ _ _ => !op.isNative
  | _ => false

/-- Every value a statement *reads*. Its destination, if it has one, is not an
operand — it is what the statement defines. Used by `Builder.assemble` to check
that a body references nothing outside its own allocation. -/
def Stmt.operands : Stmt → Array Value
  | .feltConst .. | .structNew .. => #[]
  | .feltBin _ _ lhs rhs _ => #[lhs, rhs]
  | .readMember _ self _ _ => #[self]
  | .writeMember self _ value _ => #[self, value]
  | .globalRead .. => #[]
  | .constrainEq lhs rhs _ => #[lhs, rhs]
  | .constrainIn array _ element _ => #[array, element]

/-- A function attribute this backend emits.

`function.allow_constraint` and `function.allow_witness` are deliberately not
here: `llzk-opt` infers them from the function's role and adds them itself, so
emitting them would only create a round-trip difference. -/
inductive FuncAttr where
  /-- `function.allow_non_native_field_ops`, required by `felt.uintdiv`/`felt.umod`. -/
  | allowNonNativeFieldOps
deriving DecidableEq, Repr

/-- A function parameter after SSA allocation. -/
structure Param where
  value : Value
  ty : Ty
  /-- Emitted as `function.arg_name`. `llzk-witgen --inputs` keys its JSON object
  on these names; without one it falls back to positional `arg0`, `arg1`, …. -/
  argName : Option String
deriving Repr

/-- A function parameter before SSA allocation. `Builder.component` turns each of
these into a `Param` with a freshly allocated `Value`, once per function. -/
structure ParamSpec where
  ty : Ty
  argName : Option String := none
deriving Repr

/-- A function.

The constructor is private: the only way to build one is `Builder.component`,
which allocates the parameter values, threads the body, and derives `attrs` from
the emitted statements. The fields stay readable so that `Print` and tests can
inspect them. -/
structure Func where
  private mk ::
  name : String
  params : Array Param
  body : Array Stmt
  /-- The returned value together with its type, so the rendered signature and
  the rendered `function.return` cannot disagree. -/
  result : Option (Value × Ty)
  attrs : Array FuncAttr
deriving Repr

/-- Whether a struct member is part of the component's public interface. -/
inductive Visibility where
  /-- `{llzk.pub}`. `llzk-witgen --output-scope=public` reports exactly these. -/
  | pub
  /-- `{signal}`: an internal witness cell. -/
  | signal
deriving DecidableEq, Repr

/-- A struct member: one field element or array of the component's state. -/
structure Member where
  name : String
  ty : Ty
  visibility : Visibility
deriving Repr

/-- A module-level constant array, used to materialize a lookup table:
`global.def const @name : !array.type<n x elem> = [...]`.

The rendered length comes from `values.size`, so the declared type and the
initializer cannot disagree. Elements must be canonical representatives in
`[0, p)`; `ExportTable.diagnose` is what checks that, because this module has no
notion of a prime. -/
structure ConstArray where
  name : String
  elemTy : Ty
  values : Array Nat
deriving Repr

/-- The component: state plus the `@compute`/`@constrain` pair.

Private constructor — `Builder.component` is the only way to build one, which is
what ties the two parameter lists together. The name is not a field because it is
always `rootComponent`. -/
structure StructDef where
  private mk ::
  members : Array Member
  compute : Func
  constrain : Func
deriving Repr

/-- A whole module: the globals, and the one component.

One component rather than a list, because Stage 1 inlines every subcircuit into a
single flattened circuit. `llzk.main` therefore names `rootComponent` and cannot
dangle. -/
structure Module where
  globals : Array ConstArray
  root : StructDef
deriving Repr

/-! ## Building function bodies -/

/-- Builder state: the SSA counter and the statements emitted so far. -/
structure BuilderState where
  private mk ::
  private nextIndex : Nat
  private stmts : Array Stmt

/-- The function-body builder: allocates SSA values and accumulates statements. -/
abbrev BuilderM := StateM BuilderState

namespace Builder

/-- Allocate a fresh SSA value.

Private: allocation is not definition, so a public `fresh` would let a caller
name a `%vN` no statement defines. The only allocations that are not paired with
a defining statement are the two the component builder makes itself — `%self` in
`@constrain`, and the parameters — and both are bound by the function signature. -/
private def fresh : BuilderM Value := fun s =>
  (⟨s.nextIndex⟩, { s with nextIndex := s.nextIndex + 1 })

/-- Append a statement that defines no value. -/
private def emit (stmt : Stmt) : BuilderM Unit := fun s =>
  ((), { s with stmts := s.stmts.push stmt })

/-- Allocate a fresh value, append the statement that defines it, and return it. -/
private def emitValue (mkStmt : Value → Stmt) : BuilderM Value := do
  let dst ← fresh
  emit (mkStmt dst)
  return dst

/-! ### Typed emitters

One per statement form, so no caller constructs a `Stmt` by hand, and every value
a caller holds came back from one of these. -/

/-- `%dst = felt.const value : ty` -/
def feltConst (value : Nat) (ty : Ty) : BuilderM Value :=
  emitValue (.feltConst · value ty)

/-- `%dst = felt.<op> %lhs, %rhs : ty, ty` -/
def feltBin (op : FeltBinOp) (lhs rhs : Value) (ty : Ty) : BuilderM Value :=
  emitValue (.feltBin · op lhs rhs ty)

/-- `%dst = struct.readm %self[@member] : !struct.type<@Main>, memberTy` -/
def readMember (self : Value) (member : String) (memberTy : Ty) : BuilderM Value :=
  emitValue (.readMember · self member memberTy)

/-- `struct.writem %self[@member] = %value : !struct.type<@Main>, memberTy` -/
def writeMember (self : Value) (member : String) (value : Value) (memberTy : Ty) :
    BuilderM Unit :=
  emit (.writeMember self member value memberTy)

/-- `%dst = global.read @name : ty` -/
def globalRead (name : String) (ty : Ty) : BuilderM Value :=
  emitValue (.globalRead · name ty)

/-- `constrain.eq %lhs, %rhs : ty, ty` -/
def constrainEq (lhs rhs : Value) (ty : Ty) : BuilderM Unit :=
  emit (.constrainEq lhs rhs ty)

/-- `constrain.in %array, %element : arrayTy, elementTy` -/
def constrainIn (array : Value) (arrayTy : Ty) (element : Value) (elementTy : Ty) :
    BuilderM Unit :=
  emit (.constrainIn array arrayTy element elementTy)

/-! ### Building the component

There is no general "build a function" entry point, because an LLZK component has
exactly two functions and this backend emits nothing else. Both bodies are handed
`%self` and the input values *directly* rather than as one array to index into,
so no caller has an out-of-range case to handle, and both allocate every
parameter before the body runs, so body values cannot collide with parameters.

`attrs` is derived per function from the statements actually emitted, so a
function using `felt.uintdiv`/`felt.umod` cannot be rendered without
`function.allow_non_native_field_ops`.

`Except`-valued over an arbitrary error type: this module has no notion of
diagnostics, but a lowering does, and threading its failures out of the bodies is
the only way the builder can stay the sole constructor of a `Func`. -/

/-- Allocate one SSA value per input specification. -/
private def allocParams (specs : Array ParamSpec) : BuilderM (Array Param) :=
  specs.mapM fun spec => do
    let value ← fresh
    return { value, ty := spec.ty, argName := spec.argName }

/-- Every value a function's statements and terminator reference. -/
private def referenced (stmts : Array Stmt) (result : Option (Value × Ty)) : Array Value :=
  stmts.flatMap Stmt.operands ++ (match result with | some (v, _) => #[v] | none => #[])

/-- Run a body against a fresh builder state and assemble the function.

Refuses a body that references a value it did not allocate. `Value`'s private
constructor stops a body *spelling* one; this stops it *importing* one, which
`Param.value` being a public projection otherwise allows (R4b-3). The `ε`-valued
signature has no room for a diagnostic, so the failure is a `none` — the two
callers of `component` turn it into one. -/
private def assemble {ε : Type} (name : String)
    (action : ExceptT ε BuilderM (Array Param × Option (Value × Ty))) : Except ε (Option Func) :=
  let (outcome, state) := action.run { nextIndex := 0, stmts := #[] }
  outcome.map fun (params, result) =>
    if (referenced state.stmts result).all (·.index < state.nextIndex) then
      some { name, params, body := state.stmts, result
             attrs :=
               if state.stmts.any (·.needsNonNativeFieldOps) then #[.allowNonNativeFieldOps]
               else #[] }
    else none

/-- Build the component from one parameter specification shared by both functions.

Taking `inputs` once is the point: LLZK requires `@constrain`'s argument types,
minus `%self`, to equal `@compute`'s, and there is now no way for a caller to
supply two lists that disagree.

`@compute`'s `struct.new` and `function.return %self` are emitted here rather
than by the caller, because every `@compute` does exactly that; the body's job is
only to fill `%self` in. `@constrain` takes `%self` first, then the same inputs,
and returns nothing. -/
def component {ε : Type} (members : Array Member) (inputs : Array ParamSpec)
    (computeBody : Value → Array Value → ExceptT ε BuilderM Unit)
    (constrainBody : Value → Array Value → ExceptT ε BuilderM Unit) :
    Except ε (Option StructDef) := do
  let compute ← assemble "compute" do
    let params ← allocParams inputs
    let self ← emitValue (.structNew ·)
    computeBody self (params.map (·.value))
    return (params, some (self, rootTy))
  let constrain ← assemble "constrain" do
    let self ← fresh
    let params ← allocParams inputs
    constrainBody self (params.map (·.value))
    return (#[{ value := self, ty := rootTy, argName := none }] ++ params, none)
  return match compute, constrain with
    | some compute, some constrain => some { members, compute, constrain }
    | _, _ => none

end Builder

/-- A field-valued expression the backend can emit.

`var` indices are Clean circuit variable indices; `Circuit.lean` resolves them
against the SSA values bound for the inputs and witness cells. -/
inductive FieldExpr where
  | var (index : Nat)
  /-- A field constant as its canonical representative in `[0, p)`. -/
  | const (value : Nat)
  | add (a b : FieldExpr)
  | mul (a b : FieldExpr)
  /-- Unsigned quotient of the canonical representative of `a` by the literal
  `divisor`. Witness-only: `Witness.ofFExpr` is the only recognizer that produces
  it, so it cannot appear in a constraint. See D011 for why the divisor is a
  literal and what makes the lowering faithful. -/
  | uintdiv (a : FieldExpr) (divisor : Nat)
  /-- Unsigned remainder of the canonical representative of `a` modulo the
  literal `divisor`. Witness-only; see `uintdiv`. -/
  | umod (a : FieldExpr) (divisor : Nat)
deriving DecidableEq, Repr

namespace FieldExpr

/-- The first circuit variable this expression reads at or above `bound`, if there
is one.

Used by `Analyze` to enforce the discipline Clean calls
`Operations.ComputableWitnesses`: a `.witness m` block is evaluated by
`FlatOperation.dynamicWitnesses` against the environment *before* the block, so
none of its `m` cells may read another. Checking it needs the block boundary,
which `Recognized.witnesses` has already flattened away, so it happens at
recognition time rather than in the lowering. See R2-03. -/
def firstVarAtLeast (bound : Nat) : FieldExpr → Option Nat
  | .var index => if index ≥ bound then some index else none
  | .const _ => none
  | .add a b | .mul a b => (firstVarAtLeast bound a).orElse fun _ => firstVarAtLeast bound b
  | .uintdiv a _ | .umod a _ => firstVarAtLeast bound a

/-- SSA values bound for circuit variables, indexed by circuit variable index.

Built by pushing: the inputs occupy `0 .. inputSize - 1`, then one entry per
witness cell in allocation order. Clean allocates witness offsets sequentially
from the input size, so an entry's position in this array *is* its circuit
variable index, and `size` is the next index a witness may define. -/
abbrev Env := Array Value

/-- Lowering monad: emits into a function body and may refuse. -/
abbrev LowerM := ExceptT Diagnostic BuilderM

/-- Emit the operations computing this expression, and return the SSA value
holding its result.

The only failure is a reference to a circuit variable that no input or earlier
witness defines. That is a real possibility rather than an impossible case:
`Witgen.FExpr.expr` may hold any `Expression`, including one naming a later
witness cell, and nothing in Clean's types rules that out. -/
def lower (context : String) (fieldTy : Ty) (env : Env) : FieldExpr → LowerM Value
  | .var index =>
    match env[index]? with
    | some value => pure value
    | none =>
      throw { context
              message :=
                if env.size = 0 then
                  s!"expression reads circuit variable {index}, but nothing is in scope here: \
                     the circuit has no inputs and no earlier witness cells"
                else
                  s!"expression reads circuit variable {index}, which no input or earlier \
                     witness defines; variables 0 to {env.size - 1} are in scope here" }
  | .const value => Builder.feltConst value fieldTy
  | .add a b => do
    Builder.feltBin .add (← lower context fieldTy env a) (← lower context fieldTy env b) fieldTy
  | .mul a b => do
    Builder.feltBin .mul (← lower context fieldTy env a) (← lower context fieldTy env b) fieldTy
  | .uintdiv a divisor => do
    Builder.feltBin .uintdiv (← lower context fieldTy env a) (← Builder.feltConst divisor fieldTy)
      fieldTy
  | .umod a divisor => do
    Builder.feltBin .umod (← lower context fieldTy env a) (← Builder.feltConst divisor fieldTy)
      fieldTy

end FieldExpr

/-! ## S20: the expression lowering emits exactly what a reader reads back

D018 records that G9 *validates each translation* — `compile` compares its own
output against the circuit and refuses a mismatch — rather than verifying the
translator. This is the reusable core of the stronger statement: that for the one
function which emits every constraint expression, a reader walking the emitted
statements recovers precisely the expression's denotation, so a mismatch there
cannot arise.

It lives in this module rather than beside `ofExpression` for the reason D021
records: `Value`'s constructor and the builder's internals are private, and
deliberately so, and a proof about what an emission *does* has to see them.
That is why `FieldExpr` and its lowering moved here.

The reader is stated over an arbitrary `ExprAlgebra` so that this module keeps
its independence from `Poly` and from any notion of a field;
`Clean/Backend/LLZK/Constraints.lean` instantiates it.

**What is proved and what is not.** The expression level is proved. The loops
that assemble a whole `@constrain` — the member reads, the lookups, the assertion
and output passes — are not, and `ConstraintSet.agree` is still what establishes
them. So this strengthens D018's argument without yet retiring the check. -/

/-- What an emitted expression can be read into: a carrier with the four
operations `FieldExpr` is built from. -/
structure ExprAlgebra (A : Type) where
  var : Nat → A
  const : Nat → A
  add : A → A → A
  mul : A → A → A

namespace FieldExpr

/-- The value an expression denotes in an algebra.

`uintdiv` and `umod` are witness-only and cannot appear in a constraint, so
`none` there is the same fail-closed answer the gate's reader gives. -/
def denote {A : Type} (alg : ExprAlgebra A) : FieldExpr → Option A
  | .var i => some (alg.var i)
  | .const c => some (alg.const c)
  | .add a b => (denote alg a).bind fun x => (denote alg b).map (alg.add x)
  | .mul a b => (denote alg a).bind fun x => (denote alg b).map (alg.mul x)
  | .uintdiv .. | .umod .. => none

end FieldExpr

/-- What each SSA index has been read as, where it has been read at all. -/
abbrev Assign (A : Type) := Nat → Option A

/-- Bind one index. -/
def Assign.set {A : Type} (σ : Assign A) (i : Nat) (a : A) : Assign A :=
  fun j => if j = i then some a else σ j

/-- The index a statement defines, if it defines one. -/
def Stmt.dst? : Stmt → Option Nat
  | .feltConst dst _ _ | .feltBin dst _ _ _ _ | .structNew dst
  | .readMember dst _ _ _ | .globalRead dst _ _ => some dst.index
  | .writeMember .. | .constrainEq .. | .constrainIn .. => none

/-- Read one statement. Only the two forms the expression lowering emits are
modelled; the rest leave the assignment alone, which is sound because the theorem
below quantifies over exactly the statements that lowering produced. -/
def readStmt {A : Type} (alg : ExprAlgebra A) (σ : Assign A) : Stmt → Assign A
  | .feltConst dst value _ => σ.set dst.index (alg.const value)
  | .feltBin dst op lhs rhs _ =>
    match σ lhs.index, σ rhs.index with
    | some x, some y =>
      match op with
      | .add => σ.set dst.index (alg.add x y)
      | .mul => σ.set dst.index (alg.mul x y)
      | _ => σ
    | _, _ => σ
  | _ => σ

/-- Read a statement list, left to right. -/
def readStmts {A : Type} (alg : ExprAlgebra A) (σ : Assign A) (l : List Stmt) : Assign A :=
  l.foldl (readStmt alg) σ

@[simp] theorem readStmts_nil {A} (alg : ExprAlgebra A) (σ : Assign A) :
    readStmts alg σ [] = σ := rfl

theorem readStmts_append {A} (alg : ExprAlgebra A) (σ : Assign A) (a b : List Stmt) :
    readStmts alg σ (a ++ b) = readStmts alg (readStmts alg σ a) b := by
  simp [readStmts]

/-- Reading one statement changes only the index it defines. -/
theorem readStmt_ne {A} (alg : ExprAlgebra A) (σ : Assign A) (s : Stmt) (i : Nat)
    (h : ∀ d ∈ s.dst?, i ≠ d) : readStmt alg σ s i = σ i := by
  cases s with
  | feltConst dst value ty =>
    have hne : i ≠ dst.index := h _ (by simp [Stmt.dst?])
    simp [readStmt, Assign.set, hne]
  | feltBin dst op lhs rhs ty =>
    have hne : i ≠ dst.index := h _ (by simp [Stmt.dst?])
    cases hl : σ lhs.index <;> cases hr : σ rhs.index <;> cases op <;>
      simp [readStmt, Assign.set, hne, hl, hr]
  | _ => rfl

/-- Statements that define only indices at or above `bound` cannot change what
the assignment says below it. This is what makes an earlier subexpression's value
survive a later one's emission. -/
theorem readStmts_ne {A} (alg : ExprAlgebra A) (σ : Assign A) (l : List Stmt) (i : Nat)
    (h : ∀ s ∈ l, ∀ d ∈ s.dst?, i ≠ d) : readStmts alg σ l i = σ i := by
  induction l generalizing σ with
  | nil => rfl
  | cons s rest ih =>
    rw [readStmts, List.foldl_cons, ← readStmts,
      ih _ (fun s hs => h s (List.mem_cons_of_mem _ hs))]
    exact readStmt_ne alg σ s i (h s (by simp))

theorem readStmts_below {A} (alg : ExprAlgebra A) (σ : Assign A) (l : List Stmt) (bound : Nat)
    (h : ∀ s ∈ l, ∀ d ∈ s.dst?, bound ≤ d) : ∀ i < bound, readStmts alg σ l i = σ i :=
  fun i hi => readStmts_ne alg σ l i fun s hs d hd => Nat.ne_of_lt (Nat.lt_of_lt_of_le hi (h s hs d hd))

/-- Sequencing, made visible. The linchpin: if this is `rfl`, every inductive
case of the theorem below is a rewrite rather than a monadic unfolding. -/
theorem Builder.run_bind {ε α β : Type} (f : ExceptT ε BuilderM α)
    (g : α → ExceptT ε BuilderM β) (s : BuilderState) :
    (f >>= g).run s = match f.run s with
      | (.ok a, s') => (g a).run s'
      | (.error e, s') => (.error e, s') := by
  show (ExceptT.bind f g) s = _
  unfold ExceptT.bind ExceptT.bindCont
  rcases h : f s with ⟨r, s'⟩
  cases r <;> simp [ExceptT.run, ExceptT.mk, bind, StateT.bind, pure, StateT.pure, h]

end LLZK
