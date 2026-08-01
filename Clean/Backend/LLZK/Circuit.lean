import Clean.Circuit.Formal
import Clean.Backend.LLZK.Analyze
import Clean.Backend.LLZK.Print

/-!
# Compiling a Clean circuit to an LLZK module

Reads a flattened `FormalCircuit`, runs it through `Analyze`, and lowers the
result. The lowering is total on a `Recognized` apart from one genuine failure —
an expression naming a circuit variable nothing defines — so every capability
question is settled before this module runs.

## Layout

Names are generated, not recovered: `ProvableType` preserves the flattening of a
structured value but not its member names, so there is nothing to recover. They
are stable functions of position, which is what lets golden fixtures be
meaningful.

| Clean | LLZK |
|---|---|
| input field element `i` | `@compute`/`@constrain` parameter `arg{i}` |
| witness cell `k` | member `@w{k}`, `{signal}` |
| output field element `j` | member `@out{j}`, `{llzk.pub}` |
| lookup table `T` | `global.def const @T`, queried by `constrain.in` |

Circuit variables `0 .. inputSize - 1` are the inputs and witness cell `k` is
circuit variable `inputSize + k`, because Clean allocates witness offsets
sequentially from the input size. The lowering relies on exactly that: it pushes
one environment entry per input and then one per witness cell, so an entry's
position in the environment *is* its circuit variable index.

## Why outputs get their own members

A Clean output is an arbitrary `Expression`, not necessarily a witness cell: it
may be an input, a constant, or a sum. Giving each output its own `{llzk.pub}`
member and constraining it equal to that expression therefore works uniformly,
whereas marking "the witness cell an output points at" would need a fallback for
every other shape and would make the public JSON keys depend on the layout.

The extra `constrain.eq` per output does not change what the constraint system
proves: it defines a fresh cell as equal to an expression over existing ones.
What it buys is that `llzk-witgen --output-scope=public` reports exactly the
circuit's outputs, under stable names, which is what gate G7 diffs against Clean.
-/

namespace LLZK

/-- Parameter name for input field element `i`; also its `function.arg_name`, so
`llzk-witgen --inputs` accepts `{"arg0": …}`. -/
private def inputArgName (i : Nat) : String := s!"arg{i}"

/-- Member holding witness cell `k`. -/
private def witnessMember (k : Nat) : String := s!"w{k}"

/-- Member holding output field element `j`. -/
private def outputMember (j : Nat) : String := s!"out{j}"

/-- The component's state: one `{signal}` member per witness cell, then one
`{llzk.pub}` member per output. -/
private def members (r : Recognized) (fieldTy : Ty) : Array Member :=
  (Array.range r.witnesses.size).map
      (fun k => { name := witnessMember k, ty := fieldTy, visibility := .signal })
    ++ (Array.range r.outputs.size).map
      (fun j => { name := outputMember j, ty := fieldTy, visibility := .pub })

/-- The inputs, as parameter specifications shared by both functions. -/
private def inputSpecs (r : Recognized) (fieldTy : Ty) : Array ParamSpec :=
  (Array.range r.inputSize).map fun i => { ty := fieldTy, argName := some (inputArgName i) }

/-- `@compute`: evaluate each witness cell in allocation order, then each output.

A cell is written to its member as soon as it is computed and bound in the
environment, so a later cell may read an earlier one — and only an earlier one,
which is what makes a forward reference a diagnostic rather than silently reading
an unwritten member. -/
private def lowerCompute (structTy fieldTy : Ty) (r : Recognized) : Except Diagnostic Func :=
  Builder.computeFunction structTy (inputSpecs r fieldTy) fun self inputs => do
    let mut env : FieldExpr.Env := inputs
    for (expr, k) in r.witnesses.zipIdx do
      let value ← FieldExpr.lower s!"witness cell {k}" fieldTy env expr
      Builder.writeMember self structTy (witnessMember k) value fieldTy
      env := env.push value
    for (expr, j) in r.outputs.zipIdx do
      let value ← FieldExpr.lower s!"output {j}" fieldTy env expr
      Builder.writeMember self structTy (outputMember j) value fieldTy

/-- `@constrain`: read the state back, then emit the lookups, the assertions, and
the output equalities, in that order.

The grouping does not follow the circuit's operation order. Constraints are a
conjunction, so it carries no meaning — see `Recognized`.

Clean's `assert e` means `e = 0`, so each assertion becomes `constrain.eq %e,
%zero`. The zero constant is emitted only when there is at least one assertion,
so a constraint-free component does not carry a dead value.

Each lookup reads its table's global rather than sharing one read across lookups
of the same table. Sharing would need an index from a lookup back into the
emitted globals, and a lookup into that index is a failure case the types cannot
rule out; a repeated `global.read` is pure and MLIR's CSE folds it. -/
private def lowerConstrain (structTy fieldTy : Ty) (r : Recognized) : Except Diagnostic Func :=
  Builder.constrainFunction structTy (inputSpecs r fieldTy) fun self inputs => do
    let mut env : FieldExpr.Env := inputs
    for k in Array.range r.witnesses.size do
      env := env.push (← Builder.readMember self structTy (witnessMember k) fieldTy)
    for lookup in r.lookups do
      let table ← Builder.globalRead lookup.tableName (Ty.array lookup.tableRows fieldTy)
      let value ← FieldExpr.lower s!"lookup into '{lookup.tableName}'" fieldTy env lookup.entry
      Builder.constrainIn table (Ty.array lookup.tableRows fieldTy) value fieldTy
    unless r.asserts.isEmpty do
      let zero ← Builder.feltConst 0 fieldTy
      for (expr, i) in r.asserts.zipIdx do
        let value ← FieldExpr.lower s!"assertion {i}" fieldTy env expr
        Builder.constrainEq value zero fieldTy
    for (expr, j) in r.outputs.zipIdx do
      let declared ← Builder.readMember self structTy (outputMember j) fieldTy
      let value ← FieldExpr.lower s!"output {j}" fieldTy env expr
      Builder.constrainEq declared value fieldTy

/-- Lower a recognized circuit to a one-component module.

Each used table becomes one `global.def const`. Only single-column tables reach
here — `ExportTable.diagnose` rejects wider ones — so flattening the rows is the
identity on their shape and the emitted array length is the row count. -/
def lower (cfg : Config) (name : String) (r : Recognized) : Except Diagnostic Module := do
  let fieldTy := Ty.felt cfg.field.name
  let structTy := Ty.struct name
  return {
    main := name
    globals := r.tables.map fun table => {
      name := table.name
      elemTy := fieldTy
      values := table.rows.flatMap id }
    structs := #[{
      name
      members := members r fieldTy
      compute := ← lowerCompute structTy fieldTy r
      constrain := ← lowerConstrain structTy fieldTy r }] }

variable {F : Type} [FiniteField F]

/-- Compile a circuit that has already been reduced to a `Source`. -/
def compileSource (cfg : Config) (name : String) (src : Source F) :
    Except (Array Diagnostic) Module := do
  lower cfg name (← recognize cfg src) |>.mapError (#[·])

/-- Circuits this backend can read.

Mirrors `WitgenOps`, but a `Source` also carries the output expressions and the
input size, which witness export discards. -/
class Compilable (C : Type) (F : outParam Type) [FiniteField F] where
  source : C → Source F

/-- Flatten a `FormalCircuit`: instantiate it at input variables `0 ..
size Input - 1`, run it from offset `size Input`, and inline its subcircuits.

This mirrors how `Clean.Circuit.WitnessExport` reads a formal circuit, and how
completeness statements instantiate one, so the variable numbering here is the
same one the Clean-side reference interpreter uses — which is what makes the
differential comparison in gate G7 meaningful. -/
def Source.ofFormalCircuit {Input Output : TypeMap} [ProvableType Input] [ProvableType Output]
    (c : FormalCircuit F Input Output) : Source F :=
  let instantiated := c.main (varFromOffset Input 0)
  { inputSize := size Input
    operations := (instantiated.operations (size Input)).toFlat
    outputs := (toElements (M := Output) (instantiated.output (size Input))).toArray }

instance {Input Output : TypeMap} [ProvableType Input] [ProvableType Output] :
    Compilable (FormalCircuit F Input Output) F :=
  ⟨Source.ofFormalCircuit⟩

/-- Compile a circuit to an LLZK module, or report every reason it cannot be.

`name` becomes both the component name and `llzk.main`. -/
def compile {C : Type} [Compilable C F] (cfg : Config) (name : String) (c : C) :
    Except (Array Diagnostic) Module :=
  compileSource cfg name (Compilable.source (F := F) c)

/-- Every reason a circuit cannot be compiled; empty exactly when it can. -/
def diagnostics {C : Type} [Compilable C F] (cfg : Config) (c : C) : Array Diagnostic :=
  analyze cfg (Compilable.source (F := F) c)

/-- Emit a circuit as textual LLZK, or as the diagnostics explaining why not.

The entry point behind the user-facing command. -/
def emit {C : Type} [Compilable C F] (cfg : Config) (name : String) (c : C) : String :=
  renderResult (compile cfg name c)

end LLZK
