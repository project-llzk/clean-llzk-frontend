import Clean.Circuit.Expression
import Clean.Utils.FiniteField
import Clean.Backend.LLZK.Basic
import Clean.Backend.LLZK.IR
import Clean.Backend.LLZK.Field

/-!
# The accepted field-expression language, and its lowering

`FieldExpr` is the field-valued fragment the backend can emit. It is a separate,
explicitly closed language rather than a predicate on Clean's `Expression` or on
`Witgen.FExpr`, for three reasons:

* **Recognition happens once.** Everything downstream — the lowering here, and
  the semantics theorems planned for P5 — is total, so there is no "unsupported"
  branch scattered through the emitter.
* **Growing a capability has one home.** Adding a constructor here, a case to
  each recognizer, and a case to `lower` is the whole change.
* **Constants are already canonical.** A `FieldExpr.const` holds the
  representative in `[0, p)` that `felt.const` needs, so the lowering never has
  to know what field it is in.

Constraint expressions and witness expressions share this type but not their
recognizers: `ofExpression` (here) is total and can only produce the four
arithmetic constructors, while `Witness.ofFExpr` also accepts the witness-only
forms. That is what keeps non-field operations out of `@constrain`.
-/

namespace LLZK

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

variable {F : Type} [FiniteField F] [CanonicalRepr F]

/-- Recognize a Clean circuit expression.

Total: `Expression` has exactly these four constructors, so every constraint
expression Clean can build is in the accepted subset. Nothing here can produce a
witness-only constructor, which is what keeps `@constrain` free of non-field
operations. -/
def ofExpression : Expression F → FieldExpr
  | .var v => .var v.index
  | .const c => .const (FiniteField.val c)
  | .add a b => .add (ofExpression a) (ofExpression b)
  | .mul a b => .mul (ofExpression a) (ofExpression b)

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
              message := s!"expression reads circuit variable {index}, which no input or \
                            earlier witness defines; variables 0 to {env.size - 1} are in scope \
                            here" }
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
end LLZK
