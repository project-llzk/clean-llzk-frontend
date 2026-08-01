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

end FieldExpr
end LLZK
