/-!
# A backend-local IR for the LLZK subset Clean emits

This is deliberately *not* a model of MLIR, of LLZK, or of VeIR. It models exactly
the fragment of textual LLZK described in `doc/llzk/ARCHITECTURE.md` §5, and
nothing else. Anything the frontend cannot express here must be rejected by the
analyzer before it reaches this module, which is what keeps the backend
fail-closed.

Two properties are worth stating, because they are the reason this layer exists
at all rather than the lowering concatenating strings:

* **Values are allocated, never spelled.** `Value` is opaque and only
  `BuilderM.fresh` produces one, so a lowering cannot invent an undefined SSA
  name or reuse one.
* **Malformed shapes are unrepresentable.** A `StructDef` has exactly the
  `@compute`/`@constrain` pair LLZK requires; a `Func` carries its result as one
  `Option (Value × Ty)`, so the declared return type and the returned value
  cannot disagree, and a function body cannot be missing its terminator or carry
  two.

Rendering lives in `Clean.Backend.LLZK.Print`; this module has no notion of
syntax.
-/

namespace LLZK

/-- A type in the Stage-1 LLZK subset.

`felt` carries the LLZK field-registry name (`"babybear"`, `"bn254"`, …) rather
than a prime: the registry owns the prime, and a module that disagrees with it is
rejected by `llzk-opt`. -/
inductive Ty where
  | felt (field : String)
  | array (size : Nat) (elem : Ty)
  | struct (name : String)
deriving DecidableEq, Repr, Inhabited

/-- An SSA value. Opaque by construction: only `Builder.fresh` allocates one, so
every value a statement mentions is one some earlier statement or parameter
defined. -/
structure Value where
  private mk ::
  index : Nat
deriving DecidableEq, Repr, Inhabited

/-- The binary `felt` operations Stage 1 emits.

`uintdiv` and `umod` interpret their operands as canonical representatives in
`[0, p)`. They are not field operations, so a function using them must carry
`FuncAttr.allowNonNativeFieldOps`. -/
inductive FeltBinOp where
  | add
  | sub
  | mul
  | div
  | uintdiv
  | umod
deriving DecidableEq, Repr

/-- Whether an operation is a field operation in LLZK's sense. A function whose
body contains a non-native operation must declare
`FuncAttr.allowNonNativeFieldOps`; `Func.mk` maintains that invariant. -/
def FeltBinOp.isNative : FeltBinOp → Bool
  | .add | .sub | .mul | .div => true
  | .uintdiv | .umod => false

/-- A statement in a function body.

Terminators are deliberately absent: a `Func` carries its result separately, so
a body can neither lack a terminator nor contain two. -/
inductive Stmt where
  | feltConst (dst : Value) (value : Nat) (ty : Ty)
  | feltBin (dst : Value) (op : FeltBinOp) (lhs rhs : Value) (ty : Ty)
  | structNew (dst : Value) (ty : Ty)
  | readMember (dst : Value) (self : Value) (selfTy : Ty) (member : String) (memberTy : Ty)
  | writeMember (self : Value) (selfTy : Ty) (member : String) (value : Value) (memberTy : Ty)
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

/-- A function parameter before SSA allocation. `Builder.function` turns each of
these into a `Param` with a freshly allocated `Value`. -/
structure ParamSpec where
  ty : Ty
  argName : Option String := none
deriving Repr

/-- A function.

Build these with `Builder.function`, which allocates the parameter values,
threads the body, and derives `attrs` from the emitted statements. The fields are
public so that `Print` and tests can read them. -/
structure Func where
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
initializer cannot disagree. Elements are canonical representatives in `[0, p)`. -/
structure ConstArray where
  name : String
  elemTy : Ty
  values : Array Nat
deriving Repr

/-- An LLZK component: state plus the `@compute`/`@constrain` pair.

The two functions are separate fields rather than a list because LLZK requires
exactly these two, and a struct missing one is not a component. -/
structure StructDef where
  name : String
  members : Array Member
  compute : Func
  constrain : Func
deriving Repr

/-- A whole module.

`main` names the struct that `llzk.main` points at; it is a plain `String` rather
than a reference into `structs` because rendering never needs to resolve it and
`llzk-opt` diagnoses a dangling name far better than this backend could. -/
structure Module where
  main : String
  globals : Array ConstArray
  structs : Array StructDef
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

/-- Allocate a fresh SSA value. -/
def fresh : BuilderM Value := fun s =>
  (⟨s.nextIndex⟩, { s with nextIndex := s.nextIndex + 1 })

/-- Append a statement that defines no value. -/
def emit (stmt : Stmt) : BuilderM Unit := fun s =>
  ((), { s with stmts := s.stmts.push stmt })

/-- Allocate a fresh value, append the statement that defines it, and return it. -/
def emitValue (mkStmt : Value → Stmt) : BuilderM Value := do
  let dst ← fresh
  emit (mkStmt dst)
  return dst

/-! ### Typed emitters

One per statement form, so no caller constructs a `Stmt` by hand. -/

/-- `%dst = felt.const value : ty` -/
def feltConst (value : Nat) (ty : Ty) : BuilderM Value :=
  emitValue (.feltConst · value ty)

/-- `%dst = felt.<op> %lhs, %rhs : ty, ty` -/
def feltBin (op : FeltBinOp) (lhs rhs : Value) (ty : Ty) : BuilderM Value :=
  emitValue (.feltBin · op lhs rhs ty)

/-- `%dst = struct.new : ty` -/
def structNew (ty : Ty) : BuilderM Value :=
  emitValue (.structNew · ty)

/-- `%dst = struct.readm %self[@member] : selfTy, memberTy` -/
def readMember (self : Value) (selfTy : Ty) (member : String) (memberTy : Ty) : BuilderM Value :=
  emitValue (.readMember · self selfTy member memberTy)

/-- `struct.writem %self[@member] = %value : selfTy, memberTy` -/
def writeMember (self : Value) (selfTy : Ty) (member : String) (value : Value) (memberTy : Ty) :
    BuilderM Unit :=
  emit (.writeMember self selfTy member value memberTy)

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

/-- Build a function.

Allocates one SSA value per parameter *before* running `body`, so body values can
never collide with parameters, and derives `attrs` from what was actually
emitted, so a function using `felt.uintdiv`/`felt.umod` cannot be rendered
without `function.allow_non_native_field_ops`. -/
def function (name : String) (paramSpecs : Array ParamSpec)
    (body : Array Value → BuilderM (Option (Value × Ty))) : Func :=
  let alloc : BuilderM (Array Param) :=
    paramSpecs.mapM fun spec => do
      let value ← fresh
      return { value, ty := spec.ty, argName := spec.argName }
  let build : BuilderM (Array Param × Option (Value × Ty)) := do
    let params ← alloc
    let result ← body (params.map (·.value))
    return (params, result)
  let ((params, result), state) := build { nextIndex := 0, stmts := #[] }
  { name, params, body := state.stmts, result
    attrs := if state.stmts.any (·.needsNonNativeFieldOps) then #[.allowNonNativeFieldOps] else #[] }

end Builder
end LLZK
