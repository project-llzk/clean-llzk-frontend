import Clean.Backend.LLZK.WitnessCheck
import Clean.Backend.LLZK.Examples
import Clean.Gadgets.Addition8.Addition8FullCarry
import Clean.Gadgets.ByteDecomposition.ByteDecomposition
import Clean.Gadgets.Addition32.Addition32
import Clean.Gadgets.Addition32.Addition32Full
import Clean.Gadgets.Rotation32.Rotation32
import Clean.Gadgets.Rotation64.Rotation64
import Clean.Gadgets.Not.Not64
import Clean.Gadgets.Xor.Xor32
import Clean.Gadgets.And.And8
import Clean.Gadgets.BLAKE3.BLAKE3G
import Clean.Gadgets.Keccak.Theta
import Clean.Gadgets.IsZeroField

/-!
# The coverage sweep, as a checked artifact

`ROADMAP.md`'s "Measured coverage" table was produced by an interactive session
and committed as prose (`89a6f4e8`) — R7-06 found nothing in the repository
could re-run it, and R7-05 found its headline was wrong in a way the raw
diagnostics would have shown: the counts it summarized as "`lxor`" were mostly
**unregistered-multi-column-table refusals**. S28 registers the 3-column,
65536-row `ByteXorTable` and retires that refusal, while preserving the
independent D033 range refusals.

This file is the sweep, decomposed. Every verdict in the ROADMAP table is a
`#guard` here, and the refusals are counted *by kind*, so the next coverage
claim has to move this file to drift.

Two limits, stated so they are not mistaken for coverage:

* These are `LLZK.compile` verdicts (both halves of G9 run on success); the
  compiled modules are **not** corpus entries, so no `llzk-opt` or witgen has
  seen them. The validated corpus is `Corpus.lean`.
* The universe here is the 12 gadgets the original sweep picked, plus nothing.
  `Compilable` has exactly one instance (`FormalCircuit`), so
  `GeneralFormalCircuit`, `FormalAssertion`, `FormalTable`, `InductiveTable`
  and `LookupCircuit` tops cannot even reach `compile`; `Clean/Circomlib/`,
  `Clean/Tables/`, `Clean/Examples/` and `Clean/Air/` are unmeasured. See
  `ROADMAP.md` for the honest denominators.

`SHA256Round` is absent because it requires `Fact (p > 2^33)` — no registry
field this file instantiates satisfies it at babybear — and R7-07 showed its
blockers are witness-IR features anyway (`let`-steps, `mapRange` outputs,
`>>>`), not only field width; see `Clean/Gadgets/SHA256/Add32.lean`.
-/

namespace LLZK.Test.Coverage

open Examples (withBytes withBytesAndXor)

private instance : Fact (pBabybear > 2 ^ 16 + 2 ^ 8) := ⟨by decide⟩

/-- How many diagnostics mention `sub`. The decompositions below make the S28
boundary executable: table refusals disappear while justified witness refusals
remain. -/
private def count (sub : String) (ds : Array Diagnostic) : Nat :=
  ds.foldl (fun n d => if (d.message.splitOn sub).length > 1 then n + 1 else n) 0

private def registryRefusal : String := "not in the export registry"

/-- `.error` diagnostics of a compile, or `#[]` on success — so the guards can
say "refused for exactly these reasons, in these numbers". -/
private def diags {Input Output : TypeMap} [ProvableType Input] [ProvableType Output]
    (cfg : CertifiedConfig (F pBabybear))
    (c : FormalCircuit (F pBabybear) Input Output) : Array Diagnostic :=
  match compile cfg c with
  | .ok _ => #[]
  | .error ds => ds

/-! ## The arithmetic rows: compile, with both halves of G9 as preconditions -/

#guard (compile withBytes (Gadgets.Addition8FullCarry.circuit (p := pBabybear))).toOption.isSome
#guard (compile withBytes (Gadgets.ByteDecomposition.circuit (p := pBabybear) 1)).toOption.isSome
#guard (compile withBytes (Gadgets.Addition32.circuit (p := pBabybear))).toOption.isSome
#guard (compile withBytes (Gadgets.Addition32Full.circuit (p := pBabybear))).toOption.isSome
#guard (compile withBytes (Gadgets.Rotation32.circuit (p := pBabybear) 1)).toOption.isSome
#guard (compile withBytes (Gadgets.Rotation64.circuit (p := pBabybear) 1)).toOption.isSome
#guard (compile withBytes (Gadgets.Not.circuit (p := pBabybear))).toOption.isSome

/-! ## The bitwise rows: source-visible narrowing and one retained refusal

Each guard pins the total and its decomposition. S26 removes `And8`'s `land`
diagnostic because `x &&& y ≤ x` proves the result remains below Babybear.
S29's Xor32 source executes `% 256` on every `.val` operand; Phase B proves that
literal modulo bound recursively and gives XOR/OR their common power-of-two
ceiling. Xor32 and the composed BLAKE3.G therefore compile from syntax alone,
without importing assumptions or constraints. Keccak Theta's 50 witness sites
remain raw `.val` XORs and stay refused. Xor32 joined the external corpus in
Phase X and BLAKE3.G follows in Phase H. S28 supplies the certified three-column
table, so no registry refusal remains. -/

#guard (compile withBytesAndXor (Gadgets.Xor32.circuit (p := pBabybear))).toOption.isSome

#guard (compile withBytesAndXor (Gadgets.And.And8.circuit (p := pBabybear))).toOption.isSome

#guard (compile withBytesAndXor
  (Gadgets.BLAKE3.G.circuit (p := pBabybear) 0 1 2 3)).toOption.isSome

private def theta := diags withBytesAndXor (Gadgets.Keccak256.Theta.circuit (p := pBabybear))
#guard theta.size = 50 ∧ count "lxor" theta = 50 ∧ count registryRefusal theta = 0

/-! ## The inverse row: `ite` is not the whole story

`IsZeroField`'s witness is `.ite (x =? 0) 0 x⁻¹`: the diagnostic names `ite`
because recognition stops there, but the expression also contains `inv`, a
separate later increment — so the ROADMAP's promised bitwise+`ite` increment
does not unlock this row either (R7-07). -/

private def isZero := diags withBytes (Gadgets.IsZeroField.circuit (F := F pBabybear))
#guard isZero.size = 1 ∧ count "ite" isZero = 1

end LLZK.Test.Coverage
