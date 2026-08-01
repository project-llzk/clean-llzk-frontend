import Clean.Circuit.Operations
import Clean.Backend.LLZK.Witness
import Clean.Backend.LLZK.Table

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

/-- A lookup resolved against the export registry.

Carries the table's name and row count rather than a reference into
`Recognized.tables`, so the lowering needs no indirection — and therefore has no
lookup that could fail. Both come from the same registry entry at recognition
time, so they cannot disagree with the global the module defines. -/
structure RecognizedLookup where
  tableName : String
  tableRows : Nat
  /-- The queried value. Single-column tables only, which `ExportTable.diagnose`
  enforces. -/
  entry : FieldExpr
deriving Repr

/-- A circuit recognized into the Stage-1 subset: everything the lowering needs,
and nothing it has to re-check. -/
structure Recognized where
  inputSize : Nat
  /-- One expression per witness cell, in allocation order. Entry `k` computes
  circuit variable `inputSize + k`. -/
  witnesses : Array FieldExpr
  /-- Each must evaluate to zero. Clean's `assert e` means `e = 0`. -/
  asserts : Array FieldExpr
  /-- Each queried value must be a row of its table. -/
  lookups : Array RecognizedLookup
  /-- The registry entries the circuit actually uses, in registry order. Unused
  entries are not emitted, so a shared configuration does not bloat every
  module. -/
  tables : Array ExportTable
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

/-- What one flat operation contributes: witness cells, assertions, lookups. -/
private structure Contribution where
  witnesses : Array FieldExpr := #[]
  asserts : Array FieldExpr := #[]
  lookups : Array RecognizedLookup := #[]

/-- Resolve a lookup against the registry.

Fails closed on an unregistered name and on an arity that disagrees with the
circuit's. The arity check matters: a name can match while the shape does not,
and emitting a one-column `constrain.in` against a two-column table would be a
silently weaker constraint. -/
private def recognizeLookup (tables : Array ExportTable) (context : String) (l : Lookup F) :
    Except Diagnostic RecognizedLookup := do
  let some table := tables.find? (·.name = l.table.name)
    | .error { context
               message := s!"lookup into table '{l.table.name}', which is not in the export \
                             registry; add its rows to `Config.tables` (`ExportTable.ofStatic` \
                             derives them from a `StaticTable`)" }
  if table.arity ≠ l.table.arity then
    .error { context
             message := s!"lookup into table '{l.table.name}' has arity {l.table.arity} but the \
                           registered table has arity {table.arity}" }
  else
    match l.entry.toArray with
    | #[entry] =>
      .ok { tableName := table.name, tableRows := table.rows.size
            entry := FieldExpr.ofExpression entry }
    | queried =>
      .error { context
               message := s!"lookup queries {queried.size} value(s); only single-column tables \
                             are supported" }

private def recognizeOperation (tables : Array ExportTable) (prime : Nat) (index : Nat) :
    FlatOperation F → Except Diagnostic Contribution
  | .witness _ program => do
    return { witnesses := ← Witness.recognize prime s!"operation {index} (witness)" program }
  | .assert e => .ok { asserts := #[FieldExpr.ofExpression e] }
  | .lookup l => do
    return { lookups := #[← recognizeLookup tables s!"operation {index} (lookup)" l] }
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

/-- Recognize a whole circuit, or report every reason it cannot be compiled.

The registry is diagnosed first and separately: a malformed entry is reported
even when no lookup happens to reach it, and once it is known well-formed the
per-lookup resolution has less to re-check. -/
def recognize (cfg : Config) (src : Source F) : Except (Array Diagnostic) Recognized := do
  match diagnoseRegistry cfg.tables with
  | #[] => pure ()
  | registryProblems => throw registryProblems
  let contributions ← collect
    (#[checkField (F := F) cfg |>.map fun _ => ({} : Contribution)]
      ++ (src.operations.toArray.zipIdx.map fun (op, i) =>
            recognizeOperation cfg.tables cfg.field.prime i op))
  let lookups := contributions.flatMap (·.lookups)
  return {
    inputSize := src.inputSize
    witnesses := contributions.flatMap (·.witnesses)
    asserts := contributions.flatMap (·.asserts)
    lookups
    tables := cfg.tables.filter fun table => lookups.any (·.tableName = table.name)
    outputs := src.outputs.map FieldExpr.ofExpression }

/-- Every reason the circuit cannot be compiled; empty exactly when it can.

The public form of `recognize`, for callers that want to inspect the capability
boundary without building a module. -/
def analyze (cfg : Config) (src : Source F) : Array Diagnostic :=
  match recognize cfg src with
  | .error diagnostics => diagnostics
  | .ok _ => #[]

end LLZK
