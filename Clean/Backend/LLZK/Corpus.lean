import Clean.Backend.LLZK.Examples
import Clean.Backend.LLZK.Differential
import Clean.Backend.LLZK.RendererFixture
import Clean.Backend.LLZK.WitnessCheck
import Clean.Gadgets.BLAKE3.BLAKE3G
import Clean.Gadgets.Xor.Xor32

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

/-- Whether a fixed public reference lies inside a gadget theorem's assumptions
or exercises only the executable witness program. This label is evidence
metadata; it never weakens the reference check. -/
inductive ReferenceScope where
  | spec
  | computeOnly
deriving Repr, DecidableEq

/-- Where an expected public result comes from.

Most historical corpus entries are differential checks against Clean's witness
interpreter. Promoted entries carry fixed values produced independently of
Clean. Keeping this in the same per-vector carrier as the inputs prevents a
parallel reference array from truncating or drifting by row. -/
inductive PublicExpectation where
  | fromWitness
  | fixed (scope : ReferenceScope) (values : Array Nat)
deriving Repr, DecidableEq

/-- Whether an entry permits Clean-derived public outputs or requires a fixed
reference on every vector. -/
inductive PublicReferencePolicy where
  | witnessDerived
  | fixedRequired
deriving Repr, DecidableEq

/-- One input row, its Clean witness result, and its public-output provenance. -/
structure VectorCase where
  name : String
  inputs : Array Nat
  cleanWitness : Except Diagnostic Witness
  publicExpectation : PublicExpectation
deriving Repr, DecidableEq

/-- A source row and fixed reference supplied together to the referenced-entry
constructor. There is deliberately no constructor taking parallel arrays. -/
structure ReferencedVector where
  name : String
  inputs : Array Nat
  scope : ReferenceScope
  outputs : Array Nat
deriving Repr, DecidableEq

def PublicExpectation.scope? : PublicExpectation → Option ReferenceScope
  | .fromWitness => none
  | .fixed scope _ => some scope

def PublicExpectation.isFixed : PublicExpectation → Bool
  | .fromWitness => false
  | .fixed _ _ => true

/-- Validate a vector's independent public reference and return the witness that
must be serialized. Fixed outputs replace Clean-derived outputs in both JSON
scopes only after exact width, canonicality, and complete equality checks. -/
def VectorCase.checkedWitness (vector : VectorCase) (field : FieldSpec)
    (policy : PublicReferencePolicy) (context : String) : Except Diagnostic Witness := do
  let witness ← match vector.cleanWitness with
    | .ok witness => .ok witness
    | .error diagnostic => .error { context, message := diagnostic.render }
  if witness.inputs != vector.inputs then
    throw { context
            message := "the stored Clean witness belongs to different inputs" }
  match vector.publicExpectation with
  | .fromWitness =>
      if policy = .fixedRequired then
        throw { context
                message := "this promoted entry requires a fixed independent public reference" }
      return witness
  | .fixed _ values =>
      if values.size != witness.outputs.size then
        throw { context
                message := s!"fixed public reference has {values.size} value(s), but Clean's \
                  witness has {witness.outputs.size}" }
      for (value, j) in values.zipIdx do
        if value ≥ field.prime then
          throw { context
                  message := s!"fixed public reference output {j} is {value}, not below the \
                    field prime {field.prime}" }
      for ((reference, clean), j) in (values.zip witness.outputs).zipIdx do
        if reference != clean then
          throw { context
                  message := s!"fixed public reference output {j} is {reference}, but Clean's \
                    witness produced {clean}" }
      return { witness with outputs := values }

/-! ## Entries

An entry carries an already-compiled module and already-computed expected
witnesses rather than a `Source`. That is what lets the corpus hold entries over
different fields — `Source F` fixes `F`, and the registry conformance entries
below range over all six of them.

`Entry.ofSource` is how a Clean circuit becomes an entry, and it still derives
the module and the expected witnesses from *one* flattening: if they came from
two separate traversals, a difference between them could be an artifact of the
harness rather than of the lowering. -/

/-- One artifact, plus the input vectors to check it on. -/
structure Entry where
  /-- The artifact's file name. Not the component name — that is always `@Main`
  (D015) — so this is where the circuit's identity survives. -/
  name : String
  /-- The registry field this entry is emitted in. Carried since A4: with G9
  reading types, "the reader accepts this module" is a question about a *field*,
  and the six `Square_*` entries are in six different ones. A `#guard` that
  hard-codes babybear answers it wrongly for five of them. -/
  field : FieldSpec
  module : Except (Array Diagnostic) Module
  /-- Each input vector, paired with Clean's witness and its public-output
  provenance. Input values are canonical representatives, one per input field
  element. Chosen to cover boundaries, not just a typical value. -/
  vectors : Array VectorCase
  /-- Promoted reference-backed entries fail if any vector is downgraded to a
  Clean-derived public expectation. -/
  publicReferencePolicy : PublicReferencePolicy
  /-- Gate G9: whether the emitted `@constrain`, read back as polynomials, is the
  same constraint system as the Clean circuit's. `none` where there is no Clean
  circuit to compare against — see `registryEntry`.

  Redundant since S17, in the sense that `compileSource'` refuses to return a
  module that fails the comparison, so a `some false` entry would also have an
  `.error` module. Kept because it distinguishes *checked* from *not applicable*,
  which the module alone cannot, and because `Test/Constraints.lean` pins how
  many entries are in each class. -/
  constraintsAgree : Option Bool
  /-- Gate G9, witness side: whether the emitted `@compute` computes the Clean
  circuit's witnesses and outputs. `none` on the same terms as
  `constraintsAgree`. -/
  witnessAgree : Option Bool

/-- Build an entry from a flattened circuit. -/
def Entry.ofSource {F : Type} [FiniteField F] [CanonicalRepr F] [DecidableEq F]
    (cfg : CertifiedConfig F) (name : String) (src : Source F) (inputs : Array (Array Nat)) :
    Entry where
  name := name
  field := cfg.field
  module := compileSourceVerified cfg src
  vectors := inputs.zipIdx.map fun (values, i) =>
    { name := s!"vector-{i}"
      inputs := values
      cleanWitness := LLZK.witness src values
      publicExpectation := .fromWitness }
  publicReferencePolicy := .witnessDerived
  -- `.toConfig` twice, because these two report on the halves of G9 *separately*
  -- and neither is the supported entry point; the module above is the one that
  -- goes through both, and it takes the certificates.
  constraintsAgree := some (ConstraintSet.agreeCompiled cfg.toConfig src)
  witnessAgree := some (match compileSource cfg.toConfig src with
    | .error _ => false
    | .ok m => WitnessSet.agree (Ty.felt cfg.field.name) src m)

/-- Build a promoted entry whose every vector carries a fixed, independently
derived public result. -/
def Entry.ofSourceReferenced {F : Type} [FiniteField F] [CanonicalRepr F] [DecidableEq F]
    (cfg : CertifiedConfig F) (name : String) (src : Source F)
    (vectors : Array ReferencedVector) : Entry :=
  let base := Entry.ofSource cfg name src #[]
  { base with
    vectors := vectors.map fun vector =>
      { name := vector.name
        inputs := vector.inputs
        cleanWitness := LLZK.witness src vector.inputs
        publicExpectation := .fixed vector.scope vector.outputs }
    publicReferencePolicy := .fixedRequired }

/-! ## Independently referenced Xor32 vectors

The seven normalized rows lie within Xor32's theorem assumptions and independently
reference its word-level XOR result. The three wide rows exercise only the
executable `% 256` witness semantics because LLZK witgen does not enforce
`@constrain`. Their fixed results are derived by the independent
word/limb oracle in `doc/llzk/evidence/S29/xor32_oracle.py`, never by Clean or an
emitted module. `Test/Corpus.lean` pins every name, input, scope, result, and
raw-XOR discriminator. -/

def xor32SpecVectors : Array ReferencedVector :=
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
       #[149, 81, 21, 89]⟩ ]

def xor32ComputeVectors : Array ReferencedVector :=
  #[ ⟨"compute_x_wide", #[256, 257, 511, 65535, 1, 2, 128, 170], .computeOnly,
       #[1, 3, 127, 85]⟩
   , ⟨"compute_y_wide", #[0, 255, 85, 170, 256, 257, 511, 65535], .computeOnly,
       #[0, 254, 170, 85]⟩
   , ⟨"compute_both_wide",
       #[2013265920, 65536, 1000, 65706, 257, 511, 65535, 2013265920], .computeOnly,
       #[1, 255, 23, 170]⟩ ]

def xor32Vectors : Array ReferencedVector := xor32SpecVectors ++ xor32ComputeVectors

def xor32Entry : Entry :=
  Entry.ofSourceReferenced withBytesAndXor "Xor32"
    (Compilable.source (Gadgets.Xor32.circuit (p := pBabybear))) xor32Vectors

/-! ## Independently referenced BLAKE3.G vectors

These six normalized rows exercise exactly `G 0 1 2 3`. Inputs flatten the
sixteen state words, then `x`, then `y`; outputs flatten the complete state.
Words use four little-endian byte limbs. The fixed results come from the
standalone official-reference transcription in
`doc/llzk/evidence/S29/blake3g_oracle.py`, not from Clean. The entry is promoted
together with its external controls, after the proof/shape boundary was
frozen. -/

private def leBytes32 (word : Nat) : Array Nat :=
  #[word % 256, word / 256 % 256, word / (256 ^ 2) % 256, word / (256 ^ 3) % 256]

private def flattenWordsLE (words : Array Nat) : Array Nat :=
  words.flatMap leBytes32

private structure Blake3GWordCase where
  name : String
  state : Array Nat
  x : Nat
  y : Nat
  updated : Array Nat

private def Blake3GWordCase.toReferenced (vector : Blake3GWordCase) : ReferencedVector :=
  { name := vector.name
    inputs := flattenWordsLE (vector.state ++ #[vector.x, vector.y])
    scope := .spec
    outputs := flattenWordsLE (vector.updated ++ vector.state.extract 4 vector.state.size) }

private def zeroState : Array Nat := Array.replicate 16 0
private def maxState : Array Nat := Array.replicate 16 (2 ^ 32 - 1)
private def alternatingState : Array Nat :=
  (Array.range 16).map fun index => if index % 2 = 0 then 0xAAAAAAAA else 0x55555555
private def carryState : Array Nat :=
  #[0x80808080, 0x00000001, 0xFFFFFFFE, 0xFFFFFFFF] ++ Array.replicate 12 0
private def highBitState : Array Nat :=
  #[0x80000000, 0x00000000, 0x80000000, 0xFFFFFFFF] ++ Array.replicate 12 0
private def markerState : Array Nat :=
  #[ 0x03020100, 0x07060504, 0x0B0A0908, 0x0F0E0D0C
   , 0xD2D1D0CF, 0xD6D5D4D3, 0xDAD9D8D7, 0xDEDDDCDB
   , 0xE2E1E0DF, 0xE6E5E4E3, 0xEAE9E8E7, 0xEEEDECEB
   , 0xF2F1F0EF, 0xF6F5F4F3, 0xFAF9F8F7, 0xFEFDFCFB ]

private def zeroUpdated : Array Nat :=
  #[0x00000000, 0x00000000, 0x00000000, 0x00000000]
private def maxUpdated : Array Nat :=
  #[0x000FFFDC, 0x3DB81BE4, 0xDC020DFE, 0xDC000DFF]
private def alternatingUpdated : Array Nat :=
  #[0xFFCFFF2D, 0x0D06D045, 0x7CA7DDA9, 0xD2003300]
private def carryUpdated : Array Nat :=
  #[0xF8487885, 0x071B9F7F, 0x7A084784, 0xFA87C807]
private def highBitUpdated : Array Nat :=
  #[0xFFF80000, 0x0301EFF0, 0x7F0007FE, 0xFF0007FF]
private def markerUpdated : Array Nat :=
  #[0x15B24E69, 0x728767CE, 0xA231C578, 0x7D0FAA5C]

private def Blake3GWordCase.canonical (vector : Blake3GWordCase) : Bool :=
  vector.state.size = 16 && vector.updated.size = 4 &&
    (vector.state ++ #[vector.x, vector.y] ++ vector.updated).all (· < 2 ^ 32)

private def blake3gWordCases : Array Blake3GWordCase :=
  #[ ⟨"spec_zero", zeroState, 0x00000000, 0x00000000, zeroUpdated⟩
   , ⟨"spec_max_bytes", maxState, 0xFFFFFFFF, 0xFFFFFFFF, maxUpdated⟩
   , ⟨"spec_alternating", alternatingState, 0xAAAAAAAA, 0x55555555,
       alternatingUpdated⟩
   , ⟨"spec_carry_heavy", carryState, 0xFFFFFFFE, 0x7FFFFFFF, carryUpdated⟩
   , ⟨"spec_high_bit", highBitState, 0x80000000, 0x00000001, highBitUpdated⟩
   , ⟨"spec_lane_markers", markerState, 0x13121110, 0x17161514, markerUpdated⟩ ]

-- `leBytes32` is intentionally total, so guard its six call sites before it
-- can truncate a malformed source/checkpoint word modulo 2^32.
#guard blake3gWordCases.size = 6
#guard blake3gWordCases.all Blake3GWordCase.canonical
#guard !Blake3GWordCase.canonical ⟨"bad-state", zeroState.set! 0 (2 ^ 32), 0, 0,
  zeroUpdated⟩
#guard !Blake3GWordCase.canonical ⟨"bad-x", zeroState, 2 ^ 32, 0, zeroUpdated⟩
#guard !Blake3GWordCase.canonical ⟨"bad-y", zeroState, 0, 2 ^ 32, zeroUpdated⟩
#guard !Blake3GWordCase.canonical ⟨"bad-output", zeroState, 0, 0,
  zeroUpdated.set! 0 (2 ^ 32)⟩

def blake3gVectors : Array ReferencedVector :=
  blake3gWordCases.map Blake3GWordCase.toReferenced

def blake3gEntry : Entry :=
  Entry.ofSourceReferenced withBytesAndXor "BLAKE3G"
    (Compilable.source (Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear))) blake3gVectors

/-! ## Registry conformance

`FieldSpec.registry` is transcribed from LLZK's `Field::initKnownFields`, and a
mistranscription is fail-*open* in one direction: a circuit over the true prime
would be rejected by `checkField`, but a circuit over a mistranscribed prime
would be accepted and emitted as `!felt.type<"name">`, after which LLZK does the
arithmetic in the real field. That is silently wrong, and it is exactly what D010
exists to prevent. Before this, only `babybear` was pinned behaviourally, by one
`Multiply` vector (R2-13).

One squaring component per registry field pins all six. `(p-1)^2 = 1` holds in
every field, so if the transcribed prime is the real one both witgen backends
report `1`; if it is not, `(p_ours - 1)^2` reduced modulo the *real* prime is
some other element and `--check-output` goes red. A `#guard` could not do this:
`(p-1)^2 % p = 1` is true of any `p`, so the check is only worth anything when
LLZK, not Lean, does the arithmetic.

These entries are also the corpus's only components with no witness cells and an
output that is not a witness cell — R2 controls S4 and S5, from the other
direction than `passthrough`/`constOut`. -/

/-- `@Main(arg0) { out0 = arg0 * arg0 }`, recognized directly.

Built as a `Recognized` rather than as a Clean `FormalCircuit` because Clean
would need a `FiniteField (F p)` instance — and a primality proof — for each of
the six primes, several of which are hundreds of bits. The lowering under test is
the same one every other entry goes through. -/
def registryEntry (spec : FieldSpec) : Entry :=
  let square : Recognized := {
    inputSize := 1
    witnesses := #[]
    asserts := #[]
    lookups := #[]
    tables := #[]
    outputs := #[.mul (.var 0) (.var 0)] }
  let x := spec.prime - 1
  { name := "Square_" ++ spec.name
    field := spec
    module := lowerRecognized (.forField spec) square
    vectors := #[{ name := "registry-boundary"
                   inputs := #[x]
                   cleanWitness := .ok {
                     inputs := #[x], cells := #[], outputs := #[x * x % spec.prime] }
                   publicExpectation := .fromWitness }]
    publicReferencePolicy := .witnessDerived
    -- No Clean circuit behind these, so there is nothing independent to compare
    -- the emitted constraints against; checking them against the `Recognized`
    -- they were built from would be the emitter checking itself.
    constraintsAgree := none
    witnessAgree := none }

/-! ## The corpus

Every artifact `lake env lean --run Clean/Backend/LLZK/EmitMain.lean` materializes
and `scripts/llzk/e2e.sh` checks. Only circuits that are expected to *compile*
belong here; the rejected ones are pinned by the golden tests instead.

A `Config` travels with each circuit entry because the field and the table
registry are part of what is being tested, not incidental. -/

def corpus : Array Entry :=
  #[ Entry.ofSource babybear "Multiply" (Compilable.source multiply)
       #[#[6, 7], #[0, 0], #[1, 2013265920], #[2013265920, 2013265920]],
     -- 0 and p-1 are the representative boundaries; 255/256/257 straddle the
     -- byte boundary the two recognized shapes split on.
     Entry.ofSource babybear "Decompose" (Compilable.source decompose)
       #[#[0], #[255], #[256], #[257], #[65535], #[2013265920]],
     -- S26's lookup-free bitwise slice. The mask exercises `felt.bit_and`
     -- across the byte boundary and at the field-representative boundary.
     Entry.ofSource babybear "LowByte" (Compilable.source lowByte)
       #[#[0], #[1], #[255], #[256], #[257], #[2013265920]],
     -- A first-class `VExpr.bitsOf` block: zero, individual/set low bits, the
     -- first discarded bit, and Babybear's largest representative.
     Entry.ofSource babybear "Bits8" (Compilable.source bits8)
       #[#[0], #[1], #[2], #[255], #[256], #[2013265920]],
     -- S28's row-valued lookup slice. Boundary bytes exercise the admitted
     -- `land` witness while the out-of-assumption values continue to compare
     -- compute semantics only (`llzk-witgen` ignores `@constrain`).
     Entry.ofSource withBytesAndXor "And8"
       (Compilable.source (Gadgets.And.And8.circuit (p := pBabybear)))
       #[#[0, 0], #[1, 2], #[128, 255], #[255, 255], #[256, 1],
         #[2013265920, 2013265920]],
     xor32Entry,
     blake3gEntry,
     -- No carry, carry out of the low byte, and both extremes of the documented
     -- input range (two bytes plus a boolean carry-in) -- then three vectors
     -- *outside* the gadget's `Assumptions`, which R2's C5 recorded as untested.
     -- The gadget's `Spec` says nothing there, but the two witness generators
     -- must still agree: `llzk-witgen` ignores `constrain()`, so an
     -- out-of-assumption input exercises exactly the `@compute` lowering, and a
     -- disagreement would be a lowering bug rather than a gadget one.
     Entry.ofSource withBytes "Addition8FullCarry"
       (Compilable.source (Gadgets.Addition8FullCarry.circuit (p := pBabybear)))
       #[#[0, 0, 0], #[1, 2, 0], #[1, 2, 1], #[255, 255, 1], #[255, 0, 0], #[128, 128, 0],
         #[256, 0, 0], #[0, 0, 7], #[2013265920, 2013265920, 1]],
     -- D008's two shapes: an output that is an input, and one that is a constant.
     Entry.ofSource babybear "Passthrough" (Compilable.source passthrough)
       #[#[0], #[7], #[2013265920]],
     Entry.ofSource babybear "ConstOut" (Compilable.source constOut)
       #[#[0], #[2013265920]],
     -- R5c's shape: a witness cell that is a bare copy of an input, with the
     -- input also used afterwards. It was a `#guard` in `Test/WitnessCheck.lean`
     -- and nothing else, so the one module whose reading the project has
     -- actually got wrong had never been shown to `llzk-opt` or to either witgen
     -- backend (R6). `@compute` writes the parameter straight into `@w0` and
     -- `@out0`, which is the case "Canonicalising copies" is about, and the
     -- vectors make both backends reproduce it.
     Entry.ofSource babybear "CopyCell" (Compilable.source copyCell)
       #[#[0], #[7], #[2013265920]] ]
  ++ FieldSpec.registry.map registryEntry

/-- Modules checked for syntax only: `llzk-opt` parses, verifies and round-trips
them, and no witness is generated. They have no input vectors by design — they
are the renderer's coverage, not a circuit's. -/
def syntaxFixtures : Array (String × Except Diagnostic Module) := RendererFixture.all

end LLZK.Corpus
