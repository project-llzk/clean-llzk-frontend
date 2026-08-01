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

* **Values are allocated, never spelled.** `Value` has a private constructor and
  `Builder.fresh` is private, so the only values a body can name are the ones the
  typed emitters returned to it and the parameters the builder handed it.
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

/-- Run a body against a fresh builder state and assemble the function. -/
private def assemble {ε : Type} (name : String)
    (action : ExceptT ε BuilderM (Array Param × Option (Value × Ty))) : Except ε Func :=
  let (outcome, state) := action.run { nextIndex := 0, stmts := #[] }
  outcome.map fun (params, result) =>
    { name, params, body := state.stmts, result
      attrs :=
        if state.stmts.any (·.needsNonNativeFieldOps) then #[.allowNonNativeFieldOps] else #[] }

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
    Except ε StructDef := do
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
  return { members, compute, constrain }

end Builder
end LLZK
