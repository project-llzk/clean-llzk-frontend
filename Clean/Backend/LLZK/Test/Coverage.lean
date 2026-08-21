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
**unregistered-multi-column-table refusals**. `ByteXorTable` is a 3-column,
65536-row table, and this backend is single-column-only (D013), so
`land`/`lor`/`lxor` + `ite` alone do not unlock the bitwise gadgets.

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

open Examples (withBytes)

private instance : Fact (pBabybear > 2 ^ 16 + 2 ^ 8) := ⟨by decide⟩

/-- How many diagnostics mention `sub`. The decompositions below are what R7-05
established: a refusal summarized as "the gadget needs `lxor`" was mostly
lookups into a table D013 cannot register. -/
private def count (sub : String) (ds : Array Diagnostic) : Nat :=
  ds.foldl (fun n d => if (d.message.splitOn sub).length > 1 then n + 1 else n) 0

private def registryRefusal : String := "not in the export registry"

/-- `.error` diagnostics of a compile, or `#[]` on success — so the guards can
say "refused for exactly these reasons, in these numbers". -/
private def diags {Input Output : TypeMap} [ProvableType Input] [ProvableType Output]
    (c : FormalCircuit (F pBabybear) Input Output) : Array Diagnostic :=
  match compile withBytes c with
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

/-! ## The bitwise rows: one safe narrowing, three explicit bound refusals

Each guard pins the total and its decomposition. S26 removes `And8`'s `land`
diagnostic because `x &&& y ≤ x` proves the result remains below Babybear.
It deliberately retains the `lxor` diagnostics: the source IR contains only
`.val` operands, while the byte bounds live in assumptions/constraints that the
witness recognizer cannot inspect. Treating those hidden bounds as available
would violate D033's theorem-or-refusal rule. The lookup half remains one per
`.lookup` operation and awaits D013's retirement (multi-column tables, S28). -/

private def xor32 := diags (Gadgets.Xor32.circuit (p := pBabybear))
#guard xor32.size = 5 ∧ count "lxor" xor32 = 1 ∧ count registryRefusal xor32 = 4

private def and8 := diags (Gadgets.And.And8.circuit (p := pBabybear))
#guard and8.size = 1 ∧ count "land" and8 = 0 ∧ count registryRefusal and8 = 1

private def blake3g := diags (Gadgets.BLAKE3.G.circuit (p := pBabybear) 0 1 2 3)
#guard blake3g.size = 20 ∧ count "lxor" blake3g = 4 ∧ count registryRefusal blake3g = 16

private def theta := diags (Gadgets.Keccak256.Theta.circuit (p := pBabybear))
#guard theta.size = 450 ∧ count "lxor" theta = 50 ∧ count registryRefusal theta = 400

/-! ## The inverse row: `ite` is not the whole story

`IsZeroField`'s witness is `.ite (x =? 0) 0 x⁻¹`: the diagnostic names `ite`
because recognition stops there, but the expression also contains `inv`, a
separate later increment — so the ROADMAP's promised bitwise+`ite` increment
does not unlock this row either (R7-07). -/

private def isZero := diags (Gadgets.IsZeroField.circuit (F := F pBabybear))
#guard isZero.size = 1 ∧ count "ite" isZero = 1

end LLZK.Test.Coverage
