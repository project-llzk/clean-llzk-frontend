import Clean.Circuit.Operations
import Clean.Backend.LLZK.Witness
import Clean.Backend.LLZK.Table

/-!
# Fail-closed analysis

Turns a Clean circuit into `Recognized`, the shape the lowering consumes, or into
every reason it cannot.

The analysis is where every *source*-side capability question is settled: the
lowering in `Circuit.lean` is total on a `Recognized` apart from one genuine
failure it cannot rule out (`FieldExpr.lower` on an expression naming a circuit
variable nothing defines — see `Circuit.lean`'s docstring). Clean's own
`#assert_exportable` is a weaker check — it rejects only `.native` witness
closures — so passing it says nothing about lowerability.

Diagnostics are collected across all operations rather than stopping at the
first. Each operation is recognized independently of the others, so a rejection
early in the circuit cannot cascade into spurious rejections later. The running
witness offset is the one piece of cross-operation state, and it advances by the
`m` a `.witness m` operation *declares* rather than by the number of cells
recognition managed to produce — so a rejected block still leaves later blocks
with the right base.
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
and nothing it has to re-check.

Splitting the operation list by kind loses the interleaving between witnesses,
assertions and lookups, and keeps only the order *within* each kind. That is
sound and deliberate:

* witness order is the layout and is preserved exactly — cell `k` is circuit
  variable `inputSize + k`, and a cell may only read earlier ones;
* assertions and lookups are a conjunction, so their relative order carries no
  meaning.

The visible consequence is that `@constrain` groups all lookups, then all
assertions, then the output equalities, rather than following source order. -/
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

variable {F : Type} [FiniteField F] [CanonicalRepr F]

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
    -- Unreachable, and kept because the match must be total. `Lookup.entry` is a
    -- `Vector (Expression F) l.table.arity`, `diagnoseRegistry` has already
    -- rejected every registered arity other than 1, and the comparison above has
    -- already forced `l.table.arity = 1` — so `entry` has exactly one element.
    -- R2-07 listed this as a rejection path with no fixture; it has none because
    -- nothing can reach it, which is a better answer than a fixture.
    | queried =>
      .error { context
               message := s!"lookup queries {queried.size} value(s); only single-column tables \
                             are supported" }

/-- Recognize one flat operation. `base` is the circuit variable a witness block
starting here would define first. -/
private def recognizeOperation (tables : Array ExportTable) (prime : Nat) (base : Nat)
    (index : Nat) : FlatOperation F → Except Diagnostic Contribution
  | .witness _ program => do
    return { witnesses := ← Witness.recognize prime s!"operation {index} (witness)" base program }
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
  match diagnoseRegistry cfg.field.prime cfg.tables with
  | #[] => pure ()
  | registryProblems => throw registryProblems
  let mut results : Array (Except Diagnostic Contribution) :=
    #[checkField (F := F) cfg |>.map fun _ => ({} : Contribution)]
  let mut base := src.inputSize
  for (op, i) in src.operations.toArray.zipIdx do
    results := results.push (recognizeOperation cfg.tables cfg.field.prime base i op)
    if let .witness m _ := op then base := base + m
  let contributions ← collect results
  let lookups := contributions.flatMap (·.lookups)
  return {
    inputSize := src.inputSize
    witnesses := contributions.flatMap (·.witnesses)
    asserts := contributions.flatMap (·.asserts)
    lookups
    tables := cfg.tables.filter fun table => lookups.any (·.tableName = table.name)
    outputs := src.outputs.map FieldExpr.ofExpression }

end LLZK
