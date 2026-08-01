import Clean.Circuit.Operations
import Clean.Backend.LLZK.Witness

/-!
# Fail-closed analysis

Turns a Clean circuit into `Recognized`, the shape the lowering consumes, or into
every reason it cannot.

The analysis is the *only* capability gate: the lowering in `Circuit.lean` is
total on a `Recognized`, so a construct that reaches LLZK text has necessarily
passed through here. Clean's own `#assert_exportable` is a weaker check — it
rejects only `.native` witness closures — so passing it says nothing about
lowerability.

Diagnostics are collected across all operations rather than stopping at the
first. Each operation is recognized independently of the others, so a rejection
early in the circuit cannot cascade into spurious rejections later.
-/

namespace LLZK

/-- The part of a Clean circuit this backend reads.

Flattened: subcircuits have already been inlined by `Operations.toFlat`, so there
is one operation list and one variable numbering. Circuit variables
`0 .. inputSize - 1` are the inputs; witness operations allocate the rest, in
order, starting at `inputSize`. -/
structure Source (F : Type) where
  inputSize : Nat
  operations : List (FlatOperation F)
  /-- The circuit's output, flattened to one expression per field element. -/
  outputs : Array (Expression F)

/-- A circuit recognized into the Stage-1 subset: everything the lowering needs,
and nothing it has to re-check. -/
structure Recognized where
  inputSize : Nat
  /-- One expression per witness cell, in allocation order. Entry `k` computes
  circuit variable `inputSize + k`. -/
  witnesses : Array FieldExpr
  /-- Each must evaluate to zero. Clean's `assert e` means `e = 0`. -/
  asserts : Array FieldExpr
  /-- One expression per output field element. -/
  outputs : Array FieldExpr
deriving Repr

/-- Split per-item results into all the failures, or all the successes.

Used to report every unsupported construct in one pass instead of making the
author rediscover them one compile at a time. -/
private def collect {α : Type} (results : Array (Except Diagnostic α)) :
    Except (Array Diagnostic) (Array α) :=
  let errors := results.filterMap fun
    | .error d => some d
    | .ok _ => none
  if errors.isEmpty then
    .ok (results.filterMap fun
      | .ok a => some a
      | .error _ => none)
  else
    .error errors

variable {F : Type} [FiniteField F]

/-- Recognize one flat operation as the witness cells and assertions it
contributes. -/
private def recognizeOperation (index : Nat) : FlatOperation F →
    Except Diagnostic (Array FieldExpr × Array FieldExpr)
  | .witness _ program => do
    let cells ← Witness.recognize s!"operation {index} (witness)" program
    return (cells, #[])
  | .assert e => .ok (#[], #[FieldExpr.ofExpression e])
  | .lookup l =>
    .error { context := s!"operation {index} (lookup)"
             message := s!"lookup into table '{l.table.name}'; lookups need the table export \
                           registry, which is a later increment" }
  | .interact i =>
    .error { context := s!"operation {index} (interact)"
             message := s!"interaction on channel '{i.channel.name}'; channel interactions are \
                           outside the scalar circuit subset" }

/-- Check that the circuit's field is the one the configuration names.

LLZK's registry owns the prime for a field name, and `llzk-opt` rejects a module
that disagrees. Comparing here turns a wrong `Config.field` into a diagnostic
rather than arithmetic that is silently in the wrong field. -/
private def checkField (cfg : Config) : Except Diagnostic Unit :=
  if FiniteField.size F = cfg.field.prime then .ok ()
  else
    .error { context := "field"
             message := s!"configured field '{cfg.field.name}' has prime {cfg.field.prime}, but \
                           the circuit's field has {FiniteField.size F} elements" }

/-- Recognize a whole circuit, or report every reason it cannot be compiled. -/
def recognize (cfg : Config) (src : Source F) : Except (Array Diagnostic) Recognized := do
  let operations ← collect
    (#[checkField (F := F) cfg |>.map fun _ => (#[], #[])]
      ++ (src.operations.toArray.zipIdx.map fun (op, i) => recognizeOperation i op))
  return {
    inputSize := src.inputSize
    witnesses := operations.flatMap (·.1)
    asserts := operations.flatMap (·.2)
    outputs := src.outputs.map FieldExpr.ofExpression }

/-- Every reason the circuit cannot be compiled; empty exactly when it can.

The public form of `recognize`, for callers that want to inspect the capability
boundary without building a module. -/
def analyze (cfg : Config) (src : Source F) : Array Diagnostic :=
  match recognize cfg src with
  | .error diagnostics => diagnostics
  | .ok _ => #[]

end LLZK
