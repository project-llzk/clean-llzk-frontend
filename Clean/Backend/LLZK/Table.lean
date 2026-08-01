import Clean.Circuit.Lookup
import Clean.Backend.LLZK.Basic

/-!
# The lookup-table export registry

Clean erases a table's concrete rows: `Table.toRaw` keeps the name, the arity and
the logical predicates, and drops a `StaticTable`'s `length` and `row`. So an
emitter cannot recover ByteTable's 256 rows by walking `Operations.toFlat`, and
the caller supplies them through `Config.tables`.

This module owns everything about that registry: deriving an entry from a
`StaticTable` where one is in scope, and checking the entries the caller wrote by
hand. What it deliberately cannot check is stated on `ExportTable`.
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
  rows := (Vector.mapFinRange table.length fun i =>
    ((toElements (M := Row) (table.row i)).map FiniteField.val).toArray).toArray

end ExportTable

/-- Whether a name can be emitted as an MLIR symbol `@name`.

Conservative on purpose: LLZK accepts more, but a table name that needs quoting
would make the rendered text depend on an escaping rule this backend does not
implement. A name outside this set is refused rather than mangled, because
mangling would silently break the correspondence with Clean's `RawTable.name`. -/
def isSymbolName (name : String) : Bool :=
  match name.toList with
  | [] => false
  | first :: rest =>
    (first.isAlpha || first = '_') && rest.all fun c => c.isAlphanum || c = '_'

namespace ExportTable

/-- Everything wrong with one registry entry, in the order it would be hit.

Checked once per compilation rather than per lookup, so a malformed entry is
reported even if no lookup happens to reach it. -/
def diagnose (table : ExportTable) : Array Diagnostic := Id.run do
  let context := s!"table '{table.name}'"
  let mut out := #[]
  unless isSymbolName table.name do
    out := out.push { context
                      message := "name is not a legal MLIR symbol; it must start with a letter \
                                  or underscore and contain only letters, digits and underscores" }
  if table.arity ≠ 1 then
    out := out.push { context
                      message := s!"arity is {table.arity}; only single-column tables are \
                                    supported, because a wider one needs an `array.new` query \
                                    and a multi-dimensional `constrain.in`" }
  if table.rows.isEmpty then
    out := out.push { context, message := "has no rows; an empty table makes every lookup \
                                            unsatisfiable, which is never intended" }
  for (row, i) in table.rows.zipIdx do
    if row.size ≠ table.arity then
      out := out.push { context
                        message := s!"row {i} has {row.size} value(s) but the arity is \
                                      {table.arity}" }
  return out

end ExportTable

/-- Every reason the registry as a whole is unusable: malformed entries, and
duplicate names. -/
def diagnoseRegistry (tables : Array ExportTable) : Array Diagnostic :=
  let duplicates := tables.zipIdx.filterMap fun (table, i) =>
    if tables.take i |>.any (·.name = table.name) then
      some { context := s!"table '{table.name}'"
             message := "is registered more than once; a lookup could not be resolved \
                         unambiguously" : Diagnostic }
    else none
  tables.flatMap ExportTable.diagnose ++ duplicates

end LLZK
