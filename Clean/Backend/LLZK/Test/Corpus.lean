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

/-! ## BLAKE3.G reference boundary before external promotion

This is intentionally a second, independently written transcription of the
six oracle rows. `blake3gEntry` is compiled and checked here, but HR keeps it
absent from the external corpus until its exact proof/shape boundary is frozen.
-/

private def blakeSrc : Source Bab :=
  Compilable.source (Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear))

private def blakeCheck (vector : VectorCase) : Except Diagnostic Witness :=
  vector.checkedWitness .babybear .fixedRequired "BLAKE3.G reference control"

private def blakeWithReference (vector : VectorCase) (values : Array Nat) : VectorCase :=
  match vector.publicExpectation with
  | .fixed scope _ => { vector with publicExpectation := .fixed scope values }
  | .fromWitness => vector

private def blakeMutateOutput (vector : VectorCase) (index : Nat) : VectorCase :=
  match vector.publicExpectation with
  | .fixed scope values =>
      { vector with publicExpectation := .fixed scope (values.set! index (values[index]! + 1)) }
  | .fromWitness => vector

private def blakeWithScope (vector : VectorCase) (scope : ReferenceScope) : VectorCase :=
  match vector.publicExpectation with
  | .fixed _ values => { vector with publicExpectation := .fixed scope values }
  | .fromWitness => vector

private def blakeCarriedReference (vector : VectorCase) : Option ReferencedVector :=
  match vector.publicExpectation with
  | .fixed scope values => some ⟨vector.name, vector.inputs, scope, values⟩
  | .fromWitness => none

private def blakeFixedValues (vector : VectorCase) : Array Nat :=
  match vector.publicExpectation with
  | .fixed _ values => values
  | .fromWitness => #[]

private def zeros (count : Nat) : Array Nat := Array.replicate count 0
private def maxBytes (count : Nat) : Array Nat := Array.replicate count 255

private def alternatingStateBytes : Array Nat :=
  (Array.range 16).flatMap fun index =>
    Array.replicate 4 (if index % 2 = 0 then 170 else 85)

private def expectedBlakeReferences : Array ReferencedVector :=
  #[ ⟨"spec_zero", zeros 72, .spec, zeros 64⟩
   , ⟨"spec_max_bytes", maxBytes 72, .spec,
       #[220, 255, 15, 0, 228, 27, 184, 61, 254, 13, 2, 220, 255, 13, 0, 220]
         ++ maxBytes 48⟩
   , ⟨"spec_alternating",
       alternatingStateBytes ++ #[170, 170, 170, 170, 85, 85, 85, 85], .spec,
       #[45, 255, 207, 255, 69, 208, 6, 13, 169, 221, 167, 124, 0, 51, 0, 210]
         ++ alternatingStateBytes.extract 16 64⟩
   , ⟨"spec_carry_heavy",
       #[128, 128, 128, 128, 1, 0, 0, 0, 254, 255, 255, 255, 255, 255, 255, 255]
         ++ zeros 48 ++ #[254, 255, 255, 255, 255, 255, 255, 127], .spec,
       #[133, 120, 72, 248, 127, 159, 27, 7, 132, 71, 8, 122, 7, 200, 135, 250]
         ++ zeros 48⟩
   , ⟨"spec_high_bit",
       #[0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 128, 255, 255, 255, 255]
         ++ zeros 48 ++ #[0, 0, 0, 128, 1, 0, 0, 0], .spec,
       #[0, 0, 248, 255, 240, 239, 1, 3, 254, 7, 0, 127, 255, 7, 0, 255]
         ++ zeros 48⟩
   , ⟨"spec_lane_markers",
       Array.range 16 ++ (Array.range 48).map (207 + ·) ++ (Array.range 8).map (16 + ·), .spec,
       #[105, 78, 178, 21, 206, 103, 135, 114, 120, 197, 49, 162, 92, 170, 15, 125]
         ++ (Array.range 48).map (207 + ·)⟩ ]

private def blakeReferencedEntry : Entry := blake3gEntry

private def blakeScopeValid (vector : ReferencedVector) : Bool :=
  vector.scope = .spec && vector.inputs.size = 72 && vector.outputs.size = 64 &&
    vector.inputs.all (· < 256) && vector.outputs.all (· < 256)

private def blakeMarkerInputs : Array Nat :=
  Array.range 16 ++ (Array.range 48).map (207 + ·) ++ (Array.range 8).map (16 + ·)

private def blakeMarkerOutputs : Array Nat :=
  #[105, 78, 178, 21, 206, 103, 135, 114, 120, 197, 49, 162, 92, 170, 15, 125]
    ++ (Array.range 48).map (207 + ·)

private def blakeMarker : VectorCase :=
  { name := "spec_lane_markers"
    inputs := blakeMarkerInputs
    cleanWitness := LLZK.witness blakeSrc blakeMarkerInputs
    publicExpectation := .fixed .spec blakeMarkerOutputs }

private def swappedXYInputs (inputs : Array Nat) : Array Nat :=
  inputs.extract 0 64 ++ inputs.extract 68 72 ++ inputs.extract 64 68

private def reinput (vector : VectorCase) (inputs : Array Nat) : VectorCase :=
  { vector with inputs, cleanWitness := LLZK.witness blakeSrc inputs }

/-! Positive carrier and exact-transcription baselines. -/

#guard blake3gVectors.size = 6
#guard blake3gVectors == expectedBlakeReferences
#guard blakeReferencedEntry.name = "BLAKE3G"
#guard blakeReferencedEntry.publicReferencePolicy = .fixedRequired
#guard blakeReferencedEntry.module.toOption.isSome
#guard blakeReferencedEntry.constraintsAgree = some true
#guard blakeReferencedEntry.witnessAgree = some true
#guard blakeReferencedEntry.vectors.size = 6
#guard blakeReferencedEntry.vectors.all fun vector => vector.publicExpectation.isFixed
#guard blakeReferencedEntry.vectors.all fun vector => (blakeCheck vector).isOk
#guard blakeReferencedEntry.vectors.map blakeCarriedReference ==
  expectedBlakeReferences.map some
#guard expectedBlakeReferences.map (·.name) ==
  #["spec_zero", "spec_max_bytes", "spec_alternating", "spec_carry_heavy",
    "spec_high_bit", "spec_lane_markers"]
#guard expectedBlakeReferences.all blakeScopeValid
#guard expectedBlakeReferences.all fun vector =>
  vector.outputs.extract 16 64 == vector.inputs.extract 16 64

-- HR is a reference freeze, not an external promotion. This guard must flip in HC.
#guard (Corpus.corpus.filter fun entry => entry.name = "BLAKE3G").isEmpty

/-! Every fixed output in every row is live, including all unchanged tail lanes. -/

#guard blakeReferencedEntry.vectors.all fun vector =>
  (Array.range 64).all fun index => !(blakeCheck (blakeMutateOutput vector index)).isOk

#guard blakeFixedValues blakeMarker ==
  #[105, 78, 178, 21, 206, 103, 135, 114, 120, 197, 49, 162, 92, 170, 15, 125]
    ++ (Array.range 48).map (207 + ·)
#guard (blakeFixedValues blakeMarker).all fun value =>
  ((blakeFixedValues blakeMarker).filter (· == value)).size = 1
#guard (blakeFixedValues blakeMarker).all (· != 0)

-- The last eight input limbs are x then y. Swapping them with a freshly
-- computed witness remains red against the fixed marker result.
#guard blakeMarker.inputs.extract 64 72 == #[16, 17, 18, 19, 20, 21, 22, 23]
#guard !(blakeCheck (reinput blakeMarker (swappedXYInputs blakeMarker.inputs))).isOk

/-! Width, scope, canonicality, policy, and input association controls. -/

#guard !(blakeCheck (blakeWithReference blakeMarker
  ((blakeFixedValues blakeMarker).extract 0 63))).isOk
#guard !(blakeCheck (blakeWithReference blakeMarker
  (blakeFixedValues blakeMarker ++ #[1]))).isOk
#guard !(blakeCheck (blakeWithReference blakeMarker
  ((blakeFixedValues blakeMarker).set! 0 pBabybear))).isOk

private def blakeDowngraded : VectorCase :=
  { blakeMarker with publicExpectation := .fromWitness }

#guard !(blakeCheck blakeDowngraded).isOk
#guard match blakeCarriedReference (blakeWithScope blakeMarker .computeOnly) with
  | some vector => !blakeScopeValid vector
  | none => false

private def blakeWrongInputs : VectorCase :=
  { blakeMarker with inputs := blakeMarker.inputs.set! 0 1 }

#guard !(blakeCheck blakeWrongInputs).isOk

private def nonByteBlakeReference : ReferencedVector :=
  { name := "spec_lane_markers"
    inputs := blakeMarkerInputs.set! 0 256
    scope := .spec
    outputs := blakeMarkerOutputs }

#guard !blakeScopeValid nonByteBlakeReference

end LLZK.Test.Corpus
