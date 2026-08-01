import Clean.Utils.Primes
import Clean.Gadgets.Equality
import Clean.Gadgets.Addition8.Addition8FullCarry
import Clean.Utils.Tactics.ProvableStructDeriving
import Clean.Utils.Tactics.CircuitProofStart
import Clean.Backend.LLZK.Circuit

/-!
# Worked examples, and the conformance corpus

The circuits this backend is tested and demonstrated against. They live in the
library rather than the test library for two reasons: they document what Stage 1
accepts and rejects, and both the golden tests
(`Clean/Backend/LLZK/Test/Circuit.lean`) and the emitter executable
(`Clean/Backend/LLZK/EmitMain.lean`) consume them, so there is one definition of
each rather than two that can drift.

`Spec` is `True` for several of these on purpose: they exist to exercise the
backend, not to state anything about the circuits. `Gadgets.Addition8FullCarry`
is the real thing — a fully proved gadget from the library.
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

def babybear : Config := { field := .babybear }

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

/-- Rejected: Lean's `Nat` modulo by zero is total, LLZK's is not. -/
def moduloByZero : FormalCircuit (F pBabybear) field Parts where
  main x := do
    let lo ← witness ((x.val % 0).toField)
    let hi ← witness ((x.val / 256).toField)
    return { lo, hi }
  Assumptions _ := True
  Spec _ _ := True
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

/-- Rejected: `felt.const` would reduce a divisor at or above the prime. -/
def divideByPrime : FormalCircuit (F pBabybear) field Parts where
  main x := do
    let lo ← witness ((x.val % 256).toField)
    let hi ← witness ((x.val / pBabybear).toField)
    return { lo, hi }
  Assumptions _ := True
  Spec _ _ := True
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

/-! ## Fail-closed fixtures -/

def mersenne : Config := { field := .mersenne31 }

/-! ## Lookup tables -/

/-- A `StaticTable` whose rows `ofStatic` derives. `Spec` is stated as
containment so that `contains_iff` is `Iff.rfl`: this fixture exists to test the
derivation, not to say anything about the table. -/
def tinyStatic : StaticTable (F pBabybear) field where
  name := "Tiny"
  length := 4
  row i := (i.val : F pBabybear)
  index x := x.val
  Spec t := ∃ i : Fin 4, t = (i.val : F pBabybear)
  contains_iff _ := Iff.rfl

#guard (ExportTable.ofStatic tinyStatic).name == "Tiny"
#guard (ExportTable.ofStatic tinyStatic).arity == 1
#guard (ExportTable.ofStatic tinyStatic).rows == #[#[0], #[1], #[2], #[3]]

/-- The byte table, as the registry sees it.

Written out rather than derived with `ExportTable.ofStatic`, because
`Gadgets.ByteTable` inlines its `StaticTable` into `Table.fromStatic` and there
is no named value to derive from. Naming that `StaticTable` in `ByteLookup.lean`
would let this be derived, but it breaks every proof that unfolds `ByteTable`
with `simp` (`Addition8FullCarry`, `U32`, `U64`), so it is a change for a Clean
session, not this one. Recorded as D012.

The rows are `0 .. 255` because `Gadgets.fromByte i = natToField i.val`, whose
canonical representative is `i.val`. -/
def byteTable : ExportTable where
  name := "Bytes"
  arity := 1
  rows := (Array.range 256).map (#[·])

def withBytes : Config := { field := .babybear, tables := #[byteTable] }

/-! ## The conformance corpus

Every artifact `lake exe llzk-emit` materializes and `scripts/llzk/e2e.sh`
checks. Only circuits that are expected to *compile* belong here; the rejected
ones are pinned by the golden tests instead.

A `Config` travels with each entry because the field and the table registry are
part of what is being tested, not incidental. -/

/-- Name, and the module the backend produces for it.

Entries are `Except` rather than pre-rendered text so the emitter can fail closed
on a corpus entry that stopped compiling, instead of writing a diagnostic dump
into a `.llzk` file for `llzk-opt` to choke on. -/
def corpus : Array (String × Except (Array Diagnostic) Module) := #[
  ("Multiply", compile babybear "Multiply" multiply),
  ("Decompose", compile babybear "Decompose" decompose),
  ("Addition8FullCarry",
    compile withBytes "Addition8FullCarry" (Gadgets.Addition8FullCarry.circuit (p := pBabybear)))]

end LLZK.Examples
