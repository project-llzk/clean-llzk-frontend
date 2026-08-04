import Clean.Circuit.Formal
import Clean.Backend.LLZK.Analyze

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
| the circuit | `struct.def @Main` — see `IR.rootComponent` and D015 |
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
`llzk-witgen --inputs` accepts `{"arg0": …}`.

Public, with the two below, because the differential harness must key its JSON on
exactly the names the emitter uses. Sharing the function is the only way that
cannot drift. -/
def inputArgName (i : Nat) : String := s!"arg{i}"

/-- Member holding witness cell `k`. -/
def witnessMember (k : Nat) : String := s!"w{k}"

/-- Member holding output field element `j`. -/
def outputMember (j : Nat) : String := s!"out{j}"

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

/-- `@compute`'s body: evaluate each witness cell in allocation order, then each
output.

A cell is written to its member as soon as it is computed and bound in the
environment, so a later cell may read an earlier one. That is sound only because
`Analyze` has already refused any cell that reads another cell of its *own*
`.witness m` block — Clean evaluates such a block against the environment before
it, and would read `0` where this reads the computed value (R2-03). Across
blocks, and from inputs, the two agree. A reference to a cell not yet in scope at
all remains a diagnostic from `FieldExpr.lower`. -/
private def computeBody (fieldTy : Ty) (r : Recognized) (self : Value) (inputs : Array Value) :
    FieldExpr.LowerM Unit := do
  let mut env : FieldExpr.Env := inputs
  for (expr, k) in r.witnesses.zipIdx do
    let value ← FieldExpr.lower s!"witness cell {k}" fieldTy env expr
    Builder.writeMember self (witnessMember k) value fieldTy
    env := env.push value
  for (expr, j) in r.outputs.zipIdx do
    let value ← FieldExpr.lower s!"output {j}" fieldTy env expr
    Builder.writeMember self (outputMember j) value fieldTy

/-- `@constrain`'s body: read the state back, then emit the lookups, the
assertions, and the output equalities, in that order.

The grouping does not follow the circuit's operation order. Constraints are a
conjunction, so it carries no meaning — see `Recognized`.

Clean's `assert e` means `e = 0`, so each assertion becomes `constrain.eq %e,
%zero`. The zero constant is emitted only when there is at least one assertion,
so a constraint-free component does not carry a dead value.

Each lookup reads its table's global rather than sharing one read across lookups
of the same table. Sharing would need an index from a lookup back into the
emitted globals, and a lookup into that index is a failure case the types cannot
rule out; a repeated `global.read` is pure and MLIR's CSE folds it. -/
private def constrainBody (fieldTy : Ty) (r : Recognized) (self : Value) (inputs : Array Value) :
    FieldExpr.LowerM Unit := do
  let mut env : FieldExpr.Env := inputs
  for k in Array.range r.witnesses.size do
    env := env.push (← Builder.readMember self (witnessMember k) fieldTy)
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
    let declared ← Builder.readMember self (outputMember j) fieldTy
    let value ← FieldExpr.lower s!"output {j}" fieldTy env expr
    Builder.constrainEq declared value fieldTy

/-- Lower a recognized circuit to a module.

The component is `@Main` — `IR.rootComponent`, fixed rather than derived from the
circuit, so that the emitted module can enter LLZK's analysis pipeline (D015).
The circuit's own name survives as the artifact's file name, which is where
`Corpus`/`EmitMain` put it.

`Builder.component` takes `inputSpecs` once and hands it to both functions, so
the two parameter lists cannot disagree (R2-04).

Each used table becomes one `global.def const`. Only single-column tables reach
here — `ExportTable.diagnose` rejects wider ones — so flattening the rows is the
identity on their shape and the emitted array length is the row count. -/
private def lower (cfg : Config) (r : Recognized) : Except Diagnostic Module := do
  -- Below every door, not beside one of them: `recognize` establishes these
  -- conditions for the circuits it accepts, but `lowerRecognized` takes a
  -- `Recognized` built by hand, and D011 stated them as though they held of
  -- every lowering. R5c showed they did not. See `FieldExpr.checkLowerable`.
  r.checkLowerable cfg.field.prime
  let fieldTy := Ty.felt cfg.field.name
  let globals := r.tables.map fun table => {
    name := table.name
    elemTy := fieldTy
    values := table.rows.flatten : ConstArray }
  match ← Builder.component (members r fieldTy) (inputSpecs r fieldTy)
      (computeBody fieldTy r) (constrainBody fieldTy r) with
  | some root => return { globals, root }
  | none =>
    .error { context := "emitter"
             message := "a lowered function referenced an SSA value it did not allocate. This is \
                         a defect in the backend, not in the circuit: please report it with the \
                         circuit that triggered it" }

/-- Lower a `Recognized` that was not produced by `recognize`, validating the
parts of `Config` that `recognize` would have.

`lower` itself is private, because it runs no validation at all: `Recognized` is
a public structure, so a caller could hand it a table name that is not a symbol,
a row value at or above the prime, or a field that is not in LLZK's registry, and
get text out with an empty diagnostic array (R4b-4). The corpus's registry
conformance entries are built this way — they have no Clean circuit behind them —
and they go through here.

This is *not* the fail-closed entry point for circuits. That is `compile`, in
`WitnessCheck.lean`, which additionally runs both halves of G9. Nothing that has
a Clean source should come through this door. -/
def lowerRecognized (cfg : Config) (r : Recognized) : Except (Array Diagnostic) Module := do
  if !FieldSpec.registry.contains cfg.field then
    throw #[{ context := "field"
              message := s!"configured field '{cfg.field.name}' with prime {cfg.field.prime} is \
                            not an entry of `FieldSpec.registry`" }]
  match diagnoseRegistry cfg.field.prime cfg.tables with
  | #[] => pure ()
  | problems => throw problems
  lower cfg r |>.mapError (#[·])

variable {F : Type} [FiniteField F]

/-- Compile a circuit that has already been reduced to a `Source`. -/
def compileSource [CanonicalRepr F] (cfg : Config) (src : Source F) :
    Except (Array Diagnostic) Module := do
  lower cfg (← recognize cfg src) |>.mapError (#[·])

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

/-! `compile` and `emit`, the public entry points, are deliberately **not** here.
They live in `Clean/Backend/LLZK/WitnessCheck.lean`, the last module in the
chain, because they run **both** halves of gate G9 on the module before returning
it — the constraint half from `Constraints.lean` and the witness half from that
module — so no caller can obtain a module from this backend that has not been
compared against its Clean source on both sides. `compileSource` above is the raw
lowering, used by those checks and by nothing else, and G12 confines it.

(This note said `Constraints.lean` until R6. That was where they lived between
S17 and S19; D020 moved them when the witness half arrived, and moving them is
the whole reason that half is also a precondition of emission.) -/

end LLZK
