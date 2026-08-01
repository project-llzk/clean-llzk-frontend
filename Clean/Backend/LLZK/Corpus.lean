import Clean.Backend.LLZK.Examples
import Clean.Backend.LLZK.Differential

/-!
# The conformance corpus

What `scripts/llzk/e2e.sh` checks: each example circuit, the configuration it is
compiled under, and the input vectors to compare Clean and LLZK on.

Separate from `Examples.lean` because importing
`Clean.Circuit.WitnessGeneration` there changes what `elaborate_circuit` sees and
the example circuits then fail to elaborate. Keeping the circuits in a module
with the narrower import avoids that entirely.
-/

namespace LLZK.Corpus

open LLZK.Examples

/-! ## The conformance corpus

Every artifact `lake exe llzk-emit` materializes and `scripts/llzk/e2e.sh`
checks. Only circuits that are expected to *compile* belong here; the rejected
ones are pinned by the golden tests instead.

A `Config` travels with each entry because the field and the table registry are
part of what is being tested, not incidental. -/

/-- One circuit, plus the inputs to check it on.

The `Source` is stored rather than the circuit so that the module and the
expected witness are derived from the *same* flattening — if they came from two
separate traversals, a difference between them could be an artifact of the
harness rather than of the lowering. -/
structure Entry where
  name : String
  config : Config
  source : Source (F pBabybear)
  /-- Input vectors, each with one canonical representative per input field
  element. Chosen to cover boundaries, not just a typical value. -/
  inputs : Array (Array Nat)

def Entry.module (e : Entry) : Except (Array Diagnostic) Module :=
  compileSource e.config e.name e.source

def Entry.witness (e : Entry) (inputs : Array Nat) : Except Diagnostic Witness :=
  LLZK.witness e.source inputs

/-- Every artifact `lake env lean --run Clean/Backend/LLZK/EmitMain.lean`
materializes and `scripts/llzk/e2e.sh` checks. -/
def corpus : Array Entry := #[
  { name := "Multiply", config := babybear
    source := Compilable.source multiply
    inputs := #[#[6, 7], #[0, 0], #[1, 2013265920], #[2013265920, 2013265920]] },
  { name := "Decompose", config := babybear
    source := Compilable.source decompose
    -- 0 and p-1 are the representative boundaries; 255/256/257 straddle the
    -- byte boundary the two recognized shapes split on.
    inputs := #[#[0], #[255], #[256], #[257], #[65535], #[2013265920]] },
  { name := "Addition8FullCarry", config := withBytes
    source := Compilable.source (Gadgets.Addition8FullCarry.circuit (p := pBabybear))
    -- No carry, carry out of the low byte, and both extremes of the documented
    -- input range (two bytes plus a boolean carry-in).
    inputs := #[#[0, 0, 0], #[1, 2, 0], #[1, 2, 1], #[255, 255, 1], #[255, 0, 0], #[128, 128, 0]] }]

end LLZK.Corpus
