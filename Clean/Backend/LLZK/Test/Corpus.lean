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

private def expectedReferences : Array ReferencedVector :=
  #[ ⟨"spec_zero", #[0, 0, 0, 0, 0, 0, 0, 0], .spec, #[0, 0, 0, 0]⟩
   , ⟨"spec_all_ones", #[255, 255, 255, 255, 0, 0, 0, 0], .spec,
       #[255, 255, 255, 255]⟩
   , ⟨"spec_high_bit", #[128, 128, 128, 128, 0, 1, 127, 255], .spec,
       #[128, 129, 255, 127]⟩
   , ⟨"spec_alternating", #[170, 85, 170, 85, 85, 170, 85, 170], .spec,
       #[255, 255, 255, 255]⟩
   , ⟨"spec_equal", #[0, 1, 128, 255, 0, 1, 128, 255], .spec, #[0, 0, 0, 0]⟩
   , ⟨"spec_lane_markers", #[1, 2, 4, 8, 16, 32, 64, 128], .spec,
       #[17, 34, 68, 136]⟩
   , ⟨"spec_mixed_word", #[18, 52, 86, 120, 135, 101, 67, 33], .spec,
       #[149, 81, 21, 89]⟩
   , ⟨"compute_x_wide", #[256, 257, 511, 65535, 1, 2, 128, 170], .computeOnly,
       #[1, 3, 127, 85]⟩
   , ⟨"compute_y_wide", #[0, 255, 85, 170, 256, 257, 511, 65535], .computeOnly,
       #[0, 254, 170, 85]⟩
   , ⟨"compute_both_wide",
       #[2013265920, 65536, 1000, 65706, 257, 511, 65535, 2013265920], .computeOnly,
       #[1, 255, 23, 170]⟩ ]

private def referencedEntry : Entry :=
  xor32Entry

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

private def withScope (vector : VectorCase) (scope : ReferenceScope) : VectorCase :=
  match vector.publicExpectation with
  | .fixed _ values => { vector with publicExpectation := .fixed scope values }
  | .fromWitness => vector

private def carriedReference (vector : VectorCase) : Option ReferencedVector :=
  match vector.publicExpectation with
  | .fixed scope values => some ⟨vector.name, vector.inputs, scope, values⟩
  | .fromWitness => none

private def normalizedInputs (inputs : Array Nat) : Bool :=
  inputs.size == 8 && inputs.all fun value => decide (value < 256)

private def scopeMatchesInputs (vector : ReferencedVector) : Bool :=
  match vector.scope with
  | .spec => normalizedInputs vector.inputs
  | .computeOnly => !normalizedInputs vector.inputs

private def fixedValues (vector : VectorCase) : Array Nat :=
  match vector.publicExpectation with
  | .fixed _ values => values
  | .fromWitness => #[]

private def narrowedOutputs (inputs : Array Nat) : Array Nat :=
  (Array.range 4).map fun i => (inputs[i]! % 256) ^^^ (inputs[4 + i]! % 256)

private def rawOutputs (inputs : Array Nat) : Array Nat :=
  (Array.range 4).map fun i => (inputs[i]! ^^^ inputs[4 + i]!) % pBabybear

private def firstFour (predicate : Nat → Bool) (inputs : Array Nat) : Bool :=
  (Array.range 4).all fun i => predicate inputs[i]!

private def lastFour (predicate : Nat → Bool) (inputs : Array Nat) : Bool :=
  (Array.range 4).all fun i => predicate inputs[4 + i]!

private def markerInputs : Array Nat := #[1, 2, 4, 8, 16, 32, 64, 128]

private def marker : VectorCase :=
  { name := "lane-markers"
    inputs := markerInputs
    cleanWitness := LLZK.witness xorSrc markerInputs
    publicExpectation := .fixed .spec #[17, 34, 68, 136] }

/-! ## Positive baselines -/

#guard referencedEntry.publicReferencePolicy = .fixedRequired
#guard xor32SpecVectors.size = 7
#guard xor32ComputeVectors.size = 3
#guard xor32Vectors == expectedReferences
#guard referencedEntry.name = "Xor32"
#guard referencedEntry.vectors.size = 10
#guard referencedEntry.vectors.all fun vector => vector.publicExpectation.isFixed
#guard referencedEntry.vectors.all fun vector => (check vector).isOk
#guard referencedEntry.vectors.map carriedReference == expectedReferences.map some
#guard (Corpus.corpus.filter fun entry => entry.name = "Xor32").size = 1
#guard (Corpus.corpus.find? fun entry => entry.name = "Xor32").map
  (fun entry => entry.vectors.map carriedReference) == some (expectedReferences.map some)
#guard expectedReferences.map (·.name) ==
  #["spec_zero", "spec_all_ones", "spec_high_bit", "spec_alternating", "spec_equal",
    "spec_lane_markers", "spec_mixed_word", "compute_x_wide", "compute_y_wide",
    "compute_both_wide"]
#guard expectedReferences.all fun vector => !vector.name.isEmpty
#guard expectedReferences.all fun vector =>
  vector.inputs.size = 8 ∧ vector.outputs.size = 4 ∧ vector.outputs.all (· < 256)
#guard expectedReferences.all scopeMatchesInputs
#guard expectedReferences.all fun vector => vector.outputs == narrowedOutputs vector.inputs
#guard xor32ComputeVectors.all fun vector =>
  (Array.range 4).all fun i => vector.outputs[i]! != (rawOutputs vector.inputs)[i]!
#guard xor32ComputeVectors.all fun vector => vector.inputs.all (· < pBabybear)

-- The three compute-only rows isolate left narrowing, right narrowing, then
-- simultaneous narrowing. Every lane exercises both directions across the
-- group; only the final row has both operands wide at once.
#guard match xor32ComputeVectors[0]? with
  | some vector => firstFour (· ≥ 256) vector.inputs ∧ lastFour (· < 256) vector.inputs
  | none => false
#guard match xor32ComputeVectors[1]? with
  | some vector => firstFour (· < 256) vector.inputs ∧ lastFour (· ≥ 256) vector.inputs
  | none => false
#guard match xor32ComputeVectors[2]? with
  | some vector => firstFour (· ≥ 256) vector.inputs ∧ lastFour (· ≥ 256) vector.inputs
  | none => false
#guard (check marker).toOption.map (·.outputs) == some #[17, 34, 68, 136]

/-! ## Every output position and several vector rows can go red -/

#guard (Array.range 4).all fun index => !(check (mutateOutput marker index)).isOk
#guard match referencedEntry.vectors[5]? with
  | some vector => (Array.range 4).all fun index => !(check (mutateOutput vector index)).isOk
  | none => false
#guard !(check (withReference marker #[17, 68, 34, 136])).isOk

-- First, middle, and last vector rows are independently checked. This is not a
-- parallel array: each mutation remains inside its own VectorCase.
#guard referencedEntry.vectors.all fun vector => !(check (mutateOutput vector 0)).isOk
#guard #[0, 5, 9].all fun i =>
  match referencedEntry.vectors[i]? with
  | some vector => !(check (mutateOutput vector 0)).isOk
  | none => false

-- Scope metadata does not affect the generic fixed-reference equality checker,
-- so the Xor-specific class predicate must independently reject a flipped row.
#guard match xor32SpecVectors[5]? with
  | some vector => !scopeMatchesInputs { vector with scope := .computeOnly }
  | none => false
#guard match xor32ComputeVectors[0]? with
  | some vector => !scopeMatchesInputs { vector with scope := .spec }
  | none => false

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

#guard match referencedEntry.vectors[5]? with
  | some vector => !(check { vector with publicExpectation := .fromWitness }).isOk
  | none => false

#guard match referencedEntry.vectors[5]? with
  | some vector =>
      let flipped := withScope vector .computeOnly
      match carriedReference flipped with
      | some reference => !scopeMatchesInputs reference
      | none => false
  | none => false

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
