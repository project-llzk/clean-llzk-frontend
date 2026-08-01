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

/-- Everything wrong with one registry entry, in the order it would be hit.

Checked once per compilation rather than per lookup, so a malformed entry is
reported even if no lookup happens to reach it.

`prime` is the configured field's, and it is what makes the value check possible:
`felt.const n` denotes `n mod p`, so a row value at or above the prime would be
emitted verbatim into `global.def const` and then denote a *different* element.
The emitted table would be a different set from the one the author wrote, with no
diagnostic — R2-02. This is distinct from D012, which is about rows the backend
cannot check; these it can. -/
def diagnose (prime : Nat) (table : ExportTable) : Array Diagnostic := Id.run do
  let context := s!"table '{table.name}'"
  let mut out := #[]
  unless isSymbolName table.name do
    out := out.push { context
                      message := "name is not a legal MLIR symbol; it must start with a letter \
                                  or underscore and contain only letters, digits and underscores" }
  if table.name = rootComponent then
    out := out.push { context
                      message := s!"has the same name as the component; the module's symbol \
                                    table cannot hold a `global.def` and a `struct.def` called \
                                    '{rootComponent}'" }
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
  for (row, i) in table.rows.zipIdx do
    for (value, j) in row.zipIdx do
      if value ≥ prime then
        out := out.push { context
                          message := s!"row {i}, value {j} is {value}, which is not below the \
                                        field prime {prime}; it is not a canonical \
                                        representative and `felt.const` would reduce it, so the \
                                        emitted table would be a different set of rows" }
  return out

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

end LLZK
