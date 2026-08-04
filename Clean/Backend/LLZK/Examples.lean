import Clean.Utils.Primes
import Clean.Gadgets.Equality
import Clean.Gadgets.Addition8.Addition8FullCarry
import Clean.Utils.Tactics.ProvableStructDeriving
import Clean.Utils.Tactics.CircuitProofStart
import Clean.Backend.LLZK.Circuit
import Clean.Backend.LLZK.TableCert

/-!
# Worked examples

The *accepted* circuits this backend is tested and demonstrated against. Every
one of them is consumed by both the golden tests
(`Clean/Backend/LLZK/Test/Circuit.lean`) and the conformance corpus
(`Clean/Backend/LLZK/Corpus.lean`), so there is one definition of each rather
than two that can drift — which is the only reason they live in the library.

**That sentence was false for `copyCell` for as long as it existed** (R6). It was
in neither: one `#guard` in `Test/WitnessCheck.lean` referred to it, so the one
shape this project has demonstrably misread — R5c's false refusal — had no golden
and never reached `llzk-opt` or either witgen backend. It is now in both. The
claim is worth keeping only if something checks it, so treat adding a circuit
here without adding it to both as the defect it is.

Circuits that exist only to be *rejected* do not meet that test and are not here:
they belong to the golden file that pins their diagnostics. Shipping
deliberately-broken fixtures in a library `Clean.lean` imports was an unforced
inconsistency (R2 §E6).

`Spec` is `True` for `decompose` on purpose: it exists to exercise the two
recognized natural shapes, not to state anything about the circuit.
`Gadgets.Addition8FullCarry` is the real thing — a fully proved gadget from the
library.
-/

namespace LLZK.Examples

/-- Two field elements. -/
structure Inputs (F : Type) where
  x : F
  y : F
deriving ProvableStruct

/-- Witness the product of the inputs and constrain it.

Specialized to Babybear rather than left generic: it is a fixture, and pinning
the field keeps the golden readable. -/
def multiply : FormalCircuit (F pBabybear) Inputs field where
  main input := do
    let ⟨x, y⟩ := input
    let z ← witness ((x * y : Expression (F pBabybear)) : Witgen.FExpr (F pBabybear))
    z === x * y
    return z
  Assumptions _ := True
  Spec input out := out = input.x * input.y
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

def babybear : CertifiedConfig (F pBabybear) := .forField .babybear

/-! ## The two recognized natural division/modulo shapes -/

/-- A field element's low byte and the rest. -/
structure Parts (F : Type) where
  lo : F
  hi : F
deriving ProvableStruct

/-- Witness both recognized shapes over the same subexpression. -/
def decompose : FormalCircuit (F pBabybear) field Parts where
  main x := do
    let lo ← witness ((x.val % 256).toField)
    let hi ← witness ((x.val / 256).toField)
    return { lo, hi }
  Assumptions _ := True
  Spec _ _ := True
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

/-! ## The two shapes D008 is about

D008 gives every output its own `{llzk.pub}` member and constrains it equal to
the lowered expression, precisely so that an output which is *not* a witness cell
needs no special case. These two circuits are that claim's coverage: before them,
every corpus output happened to be a witness cell, so the case the decision
exists for had never been emitted (R2 control S5). `passthrough` also carries a
component with no `{signal}` members and no witness cells at all (control S4). -/

/-- An output that is an input. Emits no witness cells. -/
def passthrough : FormalCircuit (F pBabybear) field field where
  main x := pure x
  Assumptions _ := True
  Spec input out := out = input
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

/-- A witness cell that is a bare copy of an input, with the input *also* used
afterwards.

R5c's counterexample, kept as a circuit rather than a hand-built `Source` because
the point is that it is a proved `FormalCircuit` whose correct module the backend
refused, blaming itself. `FieldExpr.lower` emits nothing for a bare variable, so
`@compute` writes the parameter straight into `@w0` and then into `@out0`; the
witness reader used to rename the parameter at the first write and misread the
second. See "Canonicalising copies" in `WitnessCheck.lean`. -/
def copyCell : FormalCircuit (F pBabybear) field field where
  main x := do
    let y ← witness x
    y === x
    return x
  Assumptions _ := True
  Spec input out := out = input
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

/-- An output that is a constant. Emits no witness cells and no parameters the
output depends on. -/
def constOut : FormalCircuit (F pBabybear) field field where
  main _ := pure (Expression.const 7)
  Assumptions _ := True
  Spec _ out := out = 7
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

/-! ## Lookup tables -/

/-- The byte table, as the registry sees it.

Written out rather than derived with `ExportTable.ofStatic`, because
`Gadgets.ByteTable` inlines its `StaticTable` into `Table.fromStatic` and there
is no named value to derive from. Naming that `StaticTable` in `ByteLookup.lean`
would let this be derived, but it breaks every proof that unfolds `ByteTable`
with `simp` (`Addition8FullCarry`, `U32`, `U64`), so it is a change for a Clean
session, not this one.

Being written out no longer makes it *trusted*, which is what D012 originally
recorded: `byteTable_certified` below proves these are the table's rows. The rows
are `0 .. 255` because `Gadgets.fromByte i = natToField i.val`, whose canonical
representative is `i.val`. -/
def byteTable : ExportTable where
  name := "Bytes"
  arity := 1
  rows := (Array.range 256).map (#[·])

/-- **D012, discharged for the one table the corpus uses.**

`byteTable`'s rows are written out rather than derived, which is what D012's
follow-up recorded as an open trust assumption. It is no longer one:
`byteTable_certifies` proves that exactly these values are what
`Gadgets.ByteTable` contains, and this closes the loop by `rfl` — the rows above
are `TableCert.byteRows`.

With `certified_membership`, and the range check `ExportTable.diagnose` performs,
this gives: the emitted `constrain.in` against `@Bytes` holds of a value exactly
when Clean's `ByteTable.Contains` does. -/
theorem byteTable_certified :
    byteTable.Certifies (Gadgets.ByteTable (p := pBabybear)) :=
  byteTable_certifies

/-- The configuration `Addition8FullCarry` is compiled under.

A `CertifiedConfig`, so it cannot be written down without `byteTable_certified`.
Since S24 that proof is no longer erased on the way in: `compile` takes this
type, so D012's obligation is a *precondition of emission* rather than a fact
recorded next to one. What it still does not establish is `GAPS.md` item 1's
second half — the caller picks both sides of `Certifies`. -/
def withBytes : CertifiedConfig (F pBabybear) :=
  ⟨.babybear, #[⟨byteTable, Gadgets.ByteTable, byteTable_certified⟩]⟩

end LLZK.Examples
