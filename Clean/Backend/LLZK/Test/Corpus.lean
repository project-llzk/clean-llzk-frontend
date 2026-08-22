import Clean.Backend.LLZK.Corpus
import Clean.Gadgets.Xor.Xor32

/-!
# Independent public-reference carrier controls

These controls exercise the exact pure checker used by `EmitMain`. They use
real Xor32 witnesses because that promotion is the first caller which requires
fixed references. No entry is added to the external corpus here.
-/

namespace LLZK.Test.Corpus

open LLZK.Corpus LLZK.Examples

abbrev Bab := F pBabybear

private def xorSrc : Source Bab :=
  Compilable.source (Gadgets.Xor32.circuit (p := pBabybear))

private def references : Array ReferencedVector :=
  #[ ⟨"zero", #[0, 0, 0, 0, 0, 0, 0, 0], .spec, #[0, 0, 0, 0]⟩
   , ⟨"lane-markers", #[1, 2, 4, 8, 16, 32, 64, 128], .spec, #[17, 34, 68, 136]⟩
   , ⟨"alternating", #[170, 85, 170, 85, 85, 170, 85, 170], .spec,
       #[255, 255, 255, 255]⟩ ]

private def referencedEntry : Entry :=
  Entry.ofSourceReferenced withBytesAndXor "Xor32-reference-control" xorSrc references

private def check (vector : VectorCase) : Except Diagnostic Witness :=
  vector.checkedWitness .babybear .fixedRequired "Xor32 reference control"

private def withReference (vector : VectorCase) (values : Array Nat) : VectorCase :=
  match vector.publicExpectation with
  | .fixed scope _ => { vector with publicExpectation := .fixed scope values }
  | .fromWitness => vector

private def mutateOutput (vector : VectorCase) (index : Nat) : VectorCase :=
  match vector.publicExpectation with
  | .fixed scope values =>
      { vector with publicExpectation := .fixed scope (values.set! index (values[index]! + 1)) }
  | .fromWitness => vector

private def markerInputs : Array Nat := #[1, 2, 4, 8, 16, 32, 64, 128]

private def marker : VectorCase :=
  { name := "lane-markers"
    inputs := markerInputs
    cleanWitness := LLZK.witness xorSrc markerInputs
    publicExpectation := .fixed .spec #[17, 34, 68, 136] }

/-! ## Positive baselines -/

#guard referencedEntry.publicReferencePolicy = .fixedRequired
#guard referencedEntry.vectors.size = 3
#guard referencedEntry.vectors.all fun vector => vector.publicExpectation.isFixed
#guard referencedEntry.vectors.all fun vector => (check vector).isOk
#guard (check marker).toOption.map (·.outputs) == some #[17, 34, 68, 136]

/-! ## Every output position and several vector rows can go red -/

#guard (Array.range 4).all fun index => !(check (mutateOutput marker index)).isOk
#guard !(check (withReference marker #[17, 68, 34, 136])).isOk

-- First, middle, and last vector rows are independently checked. This is not a
-- parallel array: each mutation remains inside its own VectorCase.
#guard referencedEntry.vectors.all fun vector => !(check (mutateOutput vector 0)).isOk

/-! ## Width, canonicality, policy, and carrier association -/

#guard check (withReference marker #[17, 34, 68]) = .error {
  context := "Xor32 reference control"
  message := "fixed public reference has 3 value(s), but Clean's witness has 4" }

#guard check (withReference marker #[17, 34, 68, 136, 0]) = .error {
  context := "Xor32 reference control"
  message := "fixed public reference has 5 value(s), but Clean's witness has 4" }

#guard !(check (withReference marker #[])).isOk

#guard check (withReference marker #[pBabybear, 34, 68, 136]) = .error {
  context := "Xor32 reference control"
  message := "fixed public reference output 0 is 2013265921, not below the field prime 2013265921" }

private def downgraded : VectorCase := { marker with publicExpectation := .fromWitness }

#guard check downgraded = .error {
  context := "Xor32 reference control"
  message := "this promoted entry requires a fixed independent public reference" }

-- Historical entries explicitly retain their Clean-derived differential path;
-- only a fixed-required policy makes the same carrier red.
#guard (downgraded.checkedWitness .babybear .witnessDerived "historical control").isOk

private def wrongInputs : VectorCase :=
  { marker with inputs := marker.inputs.set! 0 2 }

#guard check wrongInputs = .error {
  context := "Xor32 reference control"
  message := "the stored Clean witness belongs to different inputs" }

private def failedWitness : VectorCase :=
  { marker with cleanWitness := .error { context := "differential input", message := "failed" } }

#guard check failedWitness = .error {
  context := "Xor32 reference control"
  message := "differential input: failed" }

-- Pin the complete scalar mismatch diagnostic, not only `.isError`.
#guard check (mutateOutput marker 2) = .error {
  context := "Xor32 reference control"
  message := "fixed public reference output 2 is 69, but Clean's witness produced 68" }

end LLZK.Test.Corpus
