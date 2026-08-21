import Clean.Circuit.Lookup
import Clean.Backend.LLZK.Basic
import Clean.Backend.LLZK.IR

/-!
# The lookup-table export registry

Clean erases a table's concrete rows: `Table.toRaw` keeps the name, the arity and
the logical predicates, and drops a `StaticTable`'s `length` and `row`. So an
emitter cannot recover ByteTable's 256 rows by walking `Operations.toFlat`, and
the caller supplies them through `Config.tables`.

This module owns everything about that registry: deriving an entry from a
`StaticTable` where one is in scope, and checking the entries the caller wrote by
hand. What it deliberately cannot check is stated on `ExportTable`.

It imports `IR` for one thing only — `rootComponent`, the other symbol in the
emitted module's namespace. A table name has to be checked against it, and the
check belongs with the rest of the naming policy rather than being reasoned about
somewhere else.
-/

namespace LLZK
namespace ExportTable

variable {F : Type} [FiniteField F] {Row : TypeMap} [ProvableType Row]

/-- Derive a registry entry from a `StaticTable`.

Preferred over writing rows by hand: the rows are *computed* from the table's own
`row` function, so they cannot disagree with it. Only possible where the
`StaticTable` is still in scope — `Table.fromStatic` discards it. -/
def ofStatic (table : StaticTable F Row) : ExportTable where
  name := table.name
  arity := size Row
  rows := ((List.finRange table.length).map fun i =>
    ((toElements (M := Row) (table.row i)).map FiniteField.val).toArray).toArray

end ExportTable

/-- Whether a name can be emitted as an MLIR symbol `@name`.

Conservative on purpose: LLZK accepts more, but a table name that needs quoting
would make the rendered text depend on an escaping rule this backend does not
implement. A name outside this set is refused rather than mangled, because
mangling would silently break the correspondence with Clean's `RawTable.name`.

This is a statement about MLIR syntax living outside `Print`, which is otherwise
the only module that knows any. That is deliberate and not a layering slip:
`Print` is total by construction, so a name it could not render has to be refused
*before* it, and this module is where names enter the backend. -/
def isSymbolName (name : String) : Bool :=
  match name.toList with
  | [] => false
  | first :: rest =>
    (first.isAlpha || first = '_') && rest.all fun c => c.isAlphanum || c = '_'

namespace ExportTable

/-- The row-major values this table puts into the emitted `global.def const`, in
order. Row boundaries remain authoritative in `rows`; this flattening exists
only for LLZK's initializer syntax and canonical-value diagnostics. -/
def values (table : ExportTable) : Array Nat := table.rows.flatten

/-- Every row value that is not a canonical representative.

Split out from `diagnose` so that `values_lt_prime_of_diagnose` can be proved:
a `for`-loop over a mutable accumulator makes "the result is empty" hard to
decompose, and a `filterMap` makes it one `Array.mem_filterMap` away. -/
private def valueProblems (prime : Nat) (context : String) (table : ExportTable) :
    Array Diagnostic :=
  table.values.filterMap fun value =>
    if value < prime then none
    else some { context
                message := s!"row value {value} is not below the field prime {prime}; it is not \
                              a canonical representative and `felt.const` would reduce it, so \
                              the emitted table would be a different set of rows" }

/-- Everything wrong with one registry entry, in the order it would be hit.

Checked once per compilation rather than per lookup, so a malformed entry is
reported even if no lookup happens to reach it.

`prime` is the configured field's, and it is what makes the value check possible:
`felt.const n` denotes `n mod p`, so a row value at or above the prime would be
emitted verbatim into `global.def const` and then denote a *different* element.
The emitted table would be a different set from the one the author wrote, with no
diagnostic — R2-02. This is distinct from D012, which is about rows the backend
cannot check; these it can. -/
def diagnose (prime : Nat) (table : ExportTable) : Array Diagnostic :=
  let context := s!"table '{table.name}'"
  let when (cond : Bool) (message : String) : Array Diagnostic :=
    if cond then #[{ context, message }] else #[]
  when (!isSymbolName table.name)
      "name is not a legal MLIR symbol; it must start with a letter or underscore and contain \
       only letters, digits and underscores"
    ++ when (table.name = rootComponent)
      s!"has the same name as the component; the module's symbol table cannot hold a \
         `global.def` and a `struct.def` called '{rootComponent}'"
    ++ when (table.arity = 0)
      "has arity zero; a lookup row must contain at least one field element"
    ++ when table.rows.isEmpty
      "has no rows; an empty table makes every lookup unsatisfiable, which is never intended"
    ++ table.rows.zipIdx.filterMap (fun (row, i) =>
        if row.size = table.arity then none
        else some { context
                    message := s!"row {i} has {row.size} value(s) but the arity is \
                                  {table.arity}" })
    ++ valueProblems prime context table

/-- **A table that diagnoses clean has canonical values.**

The hypothesis `certified_membership` needs, discharged from the check the
compiler already runs rather than assumed at the call site. Without it, the
bridge from `Certifies` to "the emitted array holds exactly the table's
elements" would rest on a side condition nobody establishes. -/
theorem values_lt_prime_of_diagnose {prime : Nat} {table : ExportTable}
    (h : diagnose prime table = #[]) : ∀ n ∈ table.values, n < prime := by
  intro n hn
  by_contra hlt
  have hempty : valueProblems prime s!"table '{table.name}'" table = #[] := by
    have := congrArg Array.size h
    simp only [diagnose, Array.size_append, Array.size_empty] at this
    have : (valueProblems prime s!"table '{table.name}'" table).size = 0 := by omega
    exact Array.eq_empty_of_size_eq_zero this
  have : (∃ v ∈ table.values, ¬ v < prime) := ⟨n, hn, hlt⟩
  obtain ⟨v, hv, hvlt⟩ := this
  have : ({ context := s!"table '{table.name}'"
            message := s!"row value {v} is not below the field prime {prime}; it is not \
                          a canonical representative and `felt.const` would reduce it, so \
                          the emitted table would be a different set of rows" } : Diagnostic)
          ∈ valueProblems prime s!"table '{table.name}'" table := by
    simp only [valueProblems, Array.mem_filterMap]
    exact ⟨v, hv, by simp [hvlt]⟩
  rw [hempty] at this
  simp at this

end ExportTable

/-- Every reason the registry as a whole is unusable: malformed entries, and
duplicate names.

The component name is the other symbol in the module's namespace, so it is
checked here rather than separately — a table may not be called `Main`, and two
tables may not share a name. Reasoning about each name in isolation is what let
the collision through before (control S2). -/
def diagnoseRegistry (prime : Nat) (tables : Array ExportTable) : Array Diagnostic :=
  let duplicates := tables.zipIdx.filterMap fun (table, i) =>
    if tables.take i |>.any (·.name = table.name) then
      some { context := s!"table '{table.name}'"
             message := "is registered more than once; a lookup could not be resolved \
                         unambiguously" : Diagnostic }
    else none
  tables.flatMap (ExportTable.diagnose prime) ++ duplicates

/-- **A clean registry means every entry diagnoses clean.**

The step from "the compiler accepted the configuration" to "this table's values
are canonical", which `certified_membership` needs and which R4a-6 found nothing
supplied. `Lookups.canonical_of_recognize` is the composition. -/
theorem diagnose_of_mem_registry {prime : Nat} {tables : Array ExportTable}
    (h : diagnoseRegistry prime tables = #[]) {t : ExportTable} (ht : t ∈ tables) :
    ExportTable.diagnose prime t = #[] := by
  by_contra hne
  obtain ⟨d, hd⟩ : ∃ d, d ∈ ExportTable.diagnose prime t := by
    rcases hx : ExportTable.diagnose prime t with ⟨l⟩
    cases l with
    | nil => exact absurd hx hne
    | cons a as => exact ⟨a, by simp⟩
  have hmem : d ∈ diagnoseRegistry prime tables := by
    simp only [diagnoseRegistry, Array.mem_append]
    exact Or.inl (Array.mem_flatMap.mpr ⟨t, ht, hd⟩)
  rw [h] at hmem
  simp at hmem

end LLZK
