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
  tableArity : Nat
  /-- Every queried field expression, in column order. -/
  entry : Array FieldExpr
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

/-- Check every expression a lowering will emit, against the configured prime.

See `FieldExpr.checkLowerable` for what this rules out and for the two modules
R5c got out of the backend without it. Applied to all four expression positions,
because `Recognized` is public and a hand-built one can put a bad constant
anywhere — R5c's counterexamples were in `witnesses`, but an assertion or a
lookup entry would emit the same wrong text. -/
def Recognized.checkLowerable (prime : Nat) (r : Recognized) : Except Diagnostic Unit := do
  for (e, k) in r.witnesses.zipIdx do
    FieldExpr.checkLowerable prime s!"witness cell {k}" e
  for (e, i) in r.asserts.zipIdx do
    FieldExpr.checkLowerable prime s!"assertion {i}" e
  for (l, i) in r.lookups.zipIdx do
    for (e, j) in l.entry.zipIdx do
      FieldExpr.checkLowerable prime s!"lookup {i} into @{l.tableName}, column {j}" e
  for (e, j) in r.outputs.zipIdx do
    FieldExpr.checkLowerable prime s!"output {j}" e

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
private def recognizeLookup [CanonicalRepr F] (tables : Array ExportTable)
    (context : String) (l : Lookup F) :
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
    let queried := l.entry.toArray
    if queried.size ≠ table.arity then
      .error { context
               message := s!"lookup queries {queried.size} value(s), but table \
                             '{table.name}' has arity {table.arity}" }
    else
      .ok { tableName := table.name, tableRows := table.rows.size,
            tableArity := table.arity, entry := queried.map FieldExpr.ofExpression }

/-- Recognize one flat operation. `base` is the circuit variable a witness block
starting here would define first. -/
private def recognizeOperation [CanonicalRepr F] (tables : Array ExportTable) (prime : Nat)
    (base : Nat) (index : Nat) : FlatOperation F → Except Diagnostic Contribution
  | .witness _ program => do
    return { witnesses := ← Witness.recognize prime s!"operation {index} (witness)" base program }
  | .assert e => .ok { asserts := #[FieldExpr.ofExpression e] }
  | .lookup l => do
    return { lookups := #[← recognizeLookup tables s!"operation {index} (lookup)" l] }
  | .interact i =>
    .error { context := s!"operation {index} (interact)"
             message := s!"interaction on channel '{i.channel.name}'; channel interactions are \
                           outside the scalar circuit subset" }

/-- Check that the configured field is one LLZK knows, and is the circuit's.

**Two checks, and the first was missing until R4b found it.** Comparing only the
prime is not enough: `FieldSpec` is a public structure, so `Config.field` can be
any `(name, prime)` pair, and it is the *name* that `Print` renders into
`!felt.type<"…">` and that LLZK uses to pick the modulus. A configuration of
`{ name := "bn254", prime := 2013265921 }` passed the prime comparison, emitted a
babybear circuit typed as `bn254`, and was accepted by `llzk-opt`, both witgen
backends and both halves of G9 — because none of them look at the field name.
The `-1` coefficient the lowering emits is `p - 1` for the *configured* prime, so
the emitted constraint system was a different one. That is exactly the failure
mode D010 exists to prevent.

Requiring the whole `FieldSpec` to be a registry entry also removes the only
place a caller-supplied string reaches the renderer, which is why `Print` needs
no escaping: every other name it emits (`w{k}`, `out{j}`, `arg{i}`, `Main`) is
generated, and global names are checked by `diagnoseRegistry`. -/
private def checkField (cfg : Config) : Except Diagnostic Unit :=
  if !FieldSpec.registry.contains cfg.field then
    .error { context := "field"
             message := s!"configured field '{cfg.field.name}' with prime {cfg.field.prime} is \
                           not an entry of `FieldSpec.registry`; LLZK owns the prime for a field \
                           name, so a pair it does not know would be emitted as \
                           `!felt.type<\"{cfg.field.name}\">` and interpreted in whatever field \
                           LLZK has under that name" }
  else if FiniteField.size F ≠ cfg.field.prime then
    .error { context := "field"
             message := s!"configured field '{cfg.field.name}' has prime {cfg.field.prime}, but \
                           the circuit's field has {FiniteField.size F} elements" }
  else .ok ()

/-- One recognition result per flat operation, in order.

Split out of `recognize` so that the array `collect` is applied to is a term a
proof can name. Inline, the `for` loop's accumulator disappears into `forIn`, and
`size_eq_of_recognize` would need an induction showing the loop preserves element
zero instead of one `Array.mem_append_left` (A1). The behaviour is unchanged.

`base` is the circuit variable a witness block starting at that operation would
define first, and it advances by the `m` a `.witness m` *declares* rather than by
however many cells recognition produced — so a rejected block still leaves later
blocks with the right base, which is what makes rejection non-cascading (D009). -/
private def operationResults [CanonicalRepr F] (cfg : Config) (src : Source F) :
    Array (Except Diagnostic Contribution) := Id.run do
  let mut results : Array (Except Diagnostic Contribution) := #[]
  let mut base := src.inputSize
  for (op, i) in src.operations.toArray.zipIdx do
    results := results.push (recognizeOperation cfg.tables cfg.field.prime base i op)
    if let .witness m _ := op then base := base + m
  return results

/-- Recognize a whole circuit, or report every reason it cannot be compiled.

The registry is diagnosed first and separately: a malformed entry is reported
even when no lookup happens to reach it, and once it is known well-formed the
per-lookup resolution has less to re-check. -/
def recognize [CanonicalRepr F] (cfg : Config) (src : Source F) :
    Except (Array Diagnostic) Recognized := do
  -- `if` rather than `match … with | #[] => … | problems => …`. The two are the
  -- same function; the match is not one Lean can generate equation lemmas for
  -- (the patterns overlap), so `split at h` fails on it and nothing downstream
  -- can conclude anything from `recognize … = .ok r`. `registryOk_of_recognize`
  -- is that conclusion, and it is what discharges `certified_membership`'s
  -- canonicity hypothesis from the check the compiler already runs (A1).
  let registryProblems := diagnoseRegistry cfg.field.prime cfg.tables
  if !registryProblems.isEmpty then throw registryProblems
  let contributions ←
    collect (#[checkField (F := F) cfg |>.map fun _ => ({} : Contribution)]
      ++ operationResults cfg src)
  let lookups := contributions.flatMap (·.lookups)
  return {
    inputSize := src.inputSize
    witnesses := contributions.flatMap (·.witnesses)
    asserts := contributions.flatMap (·.asserts)
    lookups
    tables := cfg.tables.filter fun table => lookups.any (·.tableName = table.name)
    outputs := src.outputs.map FieldExpr.ofExpression }

/-! ## What a successful recognition establishes

Two facts, and they exist for one reason: `certified_membership` (`Certificate.lean`)
needs the table's values to be canonical, and R4a-6 found that hypothesis
discharged at no call site. It is discharged by checks the compiler *already
runs* — `diagnoseRegistry` and `checkField` — and until now nothing could say so,
because "the compiler ran a check" is not a proposition unless success is a
theorem about the check.

`collect` and `checkField` are private, so these live here rather than beside the
theorem that consumes them. -/

/-- `collect` returns `.ok` only if everything it was given was `.ok`. -/
private theorem collect_ok {α : Type} {results : Array (Except Diagnostic α)} {xs : Array α}
    (h : collect results = .ok xs) {e : Except Diagnostic α} (he : e ∈ results) :
    ∃ a, e = .ok a := by
  cases e with
  | ok a => exact ⟨a, rfl⟩
  | error d =>
    exfalso
    have hmem : d ∈ results.filterMap (fun | .error d => some d | .ok _ => none) :=
      Array.mem_filterMap.mpr ⟨.error d, he, rfl⟩
    have hne : ¬ (results.filterMap (fun | .error d => some d | .ok _ => none)).isEmpty = true := by
      intro hE
      rw [Array.isEmpty_iff.mp hE] at hmem
      simp at hmem
    simp only [collect] at h
    rw [if_neg hne] at h
    cases h

/-- **A recognized circuit had a clean registry.**

Every entry of `Config.tables` diagnosed clean — in particular every row value is
below the configured prime, which with `size_eq_of_recognize` is what
`ExportTable.values_lt_prime_of_diagnose` needs. -/
theorem registryOk_of_recognize [CanonicalRepr F] {cfg : Config} {src : Source F}
    {r : Recognized} (h : recognize cfg src = .ok r) :
    diagnoseRegistry cfg.field.prime cfg.tables = #[] := by
  by_cases hE : (diagnoseRegistry cfg.field.prime cfg.tables).isEmpty
  · exact Array.isEmpty_iff.mp hE
  · rw [recognize] at h
    simp only [hE, Bool.not_false, if_true] at h
    cases h

/-- **A recognized circuit's field is the configured one.**

D010 says a wrong field is a diagnostic rather than silently wrong arithmetic.
This is that sentence as a theorem, and it is what lets a `Nat` bound against
`cfg.field.prime` be read as a bound against `FiniteField.size F`. -/
theorem size_eq_of_recognize [CanonicalRepr F] {cfg : Config} {src : Source F}
    {r : Recognized} (h : recognize cfg src = .ok r) :
    FiniteField.size F = cfg.field.prime := by
  have hreg := registryOk_of_recognize h
  -- The bind on `collect` must have succeeded, or nothing after it ran.
  rcases hc : collect (#[checkField (F := F) cfg |>.map fun _ => ({} : Contribution)]
      ++ operationResults cfg src) with d | cs
  · exfalso; rw [recognize] at h; simp [hreg, hc] at h
  · obtain ⟨_, hfield⟩ :=
      collect_ok hc (e := checkField (F := F) cfg |>.map fun _ => ({} : Contribution))
        (Array.mem_append_left _ (by simp))
    -- `Except.map` sends `.error d` to `.error d`, so the field check is `.ok`,
    -- so neither of its two guards fired — and the second is D010's.
    unfold checkField at hfield
    split at hfield
    · simp [Except.map] at hfield
    · split at hfield
      · simp [Except.map] at hfield
      · rename_i hsize
        exact not_not.mp hsize

end LLZK
