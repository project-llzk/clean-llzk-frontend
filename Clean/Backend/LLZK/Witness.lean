import Clean.Circuit.WitnessIR
import Clean.Backend.LLZK.Expression

/-!
# Recognizing witness programs

Clean's witness IR is far larger than what this backend emits, so this is where
the Stage-1 capability boundary actually lives. Everything the recognizers here
reject is rejected *before* any LLZK text exists, which is what makes the backend
fail closed.

The accepted set is deliberately the smallest one that carries a real circuit,
and every rejection names the construct and says what it would take to support
it. Growing the set means adding a case here, a `FieldExpr` constructor, and a
fixture — see `doc/llzk/ROADMAP.md`.

Accepted today:

* programs of the form `.ir [] (.lit es)` — no `let`-steps, a literal output
  vector;
* within an element: `.expr`, `.const`, `.add`, `.mul`.

Everything else — `.native` closures, `let`-steps, `mapRange`/`append` outputs,
`inv`, `ofNat`, `ite`, `envGet`, `listGet`, `dataGet`, `hintGet` — is rejected.
-/

namespace LLZK

/-- Name a witness-IR constructor in a diagnostic, and say what supporting it
would require. Kept exhaustive rather than falling back to a generic message, so
a rejection tells the reader which roadmap item they are hitting. -/
private def describeFExpr {F : Type} : Witgen.FExpr F → String
  | .expr _ => "a circuit expression"
  | .envGet _ => "`envGet` (an environment read at a computed index)"
  | .const _ => "a field constant"
  | .localVar _ => "`localVar` (a reference to a `let`-step)"
  | .add _ _ => "an addition"
  | .mul _ _ => "a multiplication"
  | .inv _ => "`inv` (field inverse); it needs `felt.inv`, which is a later increment"
  | .ofNat _ =>
    "`ofNat` (a cast from the natural sort); only the recognized division and \
     modulo shapes are planned, and they are a later increment"
  | .ite _ _ _ => "`ite` (a conditional); it needs `scf.if`, which is a later increment"
  | .listGet _ _ => "`listGet` (a constant-list read); it needs the array dialect"
  | .dataGet _ _ _ _ => "`dataGet` (a read of committed prover data)"
  | .hintGet _ _ _ _ => "`hintGet` (a read of an uncommitted prover hint)"

namespace FieldExpr

variable {F : Type} [FiniteField F]

/-- Recognize a field-sorted witness expression.

`.expr` delegates to `ofExpression`, which is total, so an embedded circuit
expression is always accepted; the arithmetic constructors recurse; everything
else is refused by name. -/
def ofFExpr (context : String) : Witgen.FExpr F → Except Diagnostic FieldExpr
  | .expr e => .ok (ofExpression e)
  | .const c => .ok (.const (FiniteField.val c))
  | .add a b => return .add (← ofFExpr context a) (← ofFExpr context b)
  | .mul a b => return .mul (← ofFExpr context a) (← ofFExpr context b)
  | e => .error { context, message := "unsupported witness expression: " ++ describeFExpr e }

end FieldExpr

namespace Witness

variable {F : Type} [FiniteField F] {m : Nat}

/-- Recognize the output of a witness program: one expression per witness cell. -/
private def ofVExpr (context : String) : {n : Nat} → Witgen.VExpr F n →
    Except Diagnostic (Array FieldExpr)
  | _, .lit es => es.toArray.mapM (FieldExpr.ofFExpr context)
  | _, .mapRange _ _ =>
    .error { context
             message := "witness output is a `mapRange` loop; only literal output vectors are \
                         supported (unrolling or `scf.for` is a later increment)" }
  | _, .append _ _ =>
    .error { context
             message := "witness output is an `append`; only literal output vectors are \
                         supported" }

/-- Recognize a whole witness program as one expression per cell it produces.

The returned array has one entry per witness cell, in allocation order. -/
def recognize (context : String) : Witgen.WitgenIR F m → Except Diagnostic (Array FieldExpr)
  | .native _ =>
    .error { context
             message := "witness is a native Lean closure, which cannot be exported; port it to \
                         the witness IR (see doc/witgen-authoring.md)" }
  | .ir steps out =>
    if steps.isEmpty then ofVExpr context out
    else
      .error { context
               message := s!"witness program has {steps.length} `let`-step(s); only step-free \
                             programs are supported" }

end Witness
end LLZK
