import Clean.Backend.LLZK.Examples
import Clean.Backend.LLZK.Differential
import Clean.Backend.LLZK.RendererFixture
import Clean.Backend.LLZK.WitnessCheck

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
  module : Except (Array Diagnostic) Module
  /-- Each input vector, paired with Clean's own witness for it. Input values are
  canonical representatives, one per input field element. Chosen to cover
  boundaries, not just a typical value. -/
  vectors : Array (Array Nat × Except Diagnostic Witness)
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
  module := compileSourceVerified cfg src
  vectors := inputs.map fun values => (values, LLZK.witness src values)
  -- `.toConfig` twice, because these two report on the halves of G9 *separately*
  -- and neither is the supported entry point; the module above is the one that
  -- goes through both, and it takes the certificates.
  constraintsAgree := some (ConstraintSet.agreeCompiled cfg.toConfig src)
  witnessAgree := some (match compileSource cfg.toConfig src with
    | .error _ => false
    | .ok m => WitnessSet.agree src m)

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
    module := lowerRecognized (.forField spec) square
    vectors := #[(#[x], .ok { inputs := #[x], cells := #[], outputs := #[x * x % spec.prime] })]
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
