/-!
# Backend vocabulary: diagnostics, the LLZK field registry, and configuration

Shared by the analyzer, the lowering, and the user-facing command. Deliberately
free of any dependency on the emitter IR: these are statements about the *source*
side of the translation.
-/

namespace LLZK

/-- A reason the backend refused to compile a circuit.

The backend is fail-closed: a non-empty diagnostic array means no LLZK text is
produced. `context` locates the problem in the circuit — a flat operation index,
an output position — and `message` says what is unsupported and, where there is
one, what to do instead. -/
structure Diagnostic where
  context : String
  message : String
deriving DecidableEq, Repr

def Diagnostic.render (d : Diagnostic) : String :=
  d.context ++ ": " ++ d.message

/-- A prime field in LLZK's built-in registry.

LLZK's registry owns the prime; a module that names a registry field is checked
against it by `llzk-opt`, and one that disagrees is rejected. Emitting
`!felt.type<name>` for a Clean circuit is therefore only sound if the circuit's
prime is exactly `prime`, which is why the name and the prime travel together and
`Analyze` compares them rather than trusting the caller's spelling.

Transcribed from `lib/Util/Field.cpp`, `Field::initKnownFields`, at the pinned
LLZK revision `5db6f8f9baaa40787a1a40625796497445f2da36`. -/
structure FieldSpec where
  name : String
  prime : Nat
deriving DecidableEq, Repr

namespace FieldSpec

/-- `15 * 2^27 + 1`; Clean's `pBabybear`. -/
def babybear : FieldSpec := { name := "babybear", prime := 2013265921 }

/-- `2^31 - 1`; Clean's `pMersenne`. -/
def mersenne31 : FieldSpec := { name := "mersenne31", prime := 2147483647 }

/-- `2^31 - 2^24 + 1`. -/
def koalabear : FieldSpec := { name := "koalabear", prime := 2130706433 }

/-- `2^64 - 2^32 + 1`. -/
def goldilocks : FieldSpec := { name := "goldilocks", prime := 18446744069414584321 }

/-- The BN254 scalar field, circom's default. LLZK registers the same prime under
both `bn254` and `bn128`; this backend emits the `bn254` spelling. -/
def bn254 : FieldSpec :=
  { name := "bn254"
    prime := 21888242871839275222246405745257275088548364400416034343698204186575808495617 }

/-- The Grumpkin scalar field. -/
def grumpkin : FieldSpec :=
  { name := "grumpkin"
    prime := 21888242871839275222246405745257275088696311157297823662689037894645226208583 }

/-- Every field this backend will emit, in the order it is searched. A field
outside this list must be added here, with its prime, rather than passed as a
bare string. -/
def registry : Array FieldSpec :=
  #[babybear, mersenne31, koalabear, goldilocks, bn254, grumpkin]

/-- The registry entry for a prime, if LLZK knows one. -/
def ofPrime? (p : Nat) : Option FieldSpec :=
  registry.find? (·.prime = p)

end FieldSpec

/-- What the backend needs beyond the circuit itself.

Kept small on purpose. Anything that changes the *meaning* of the output belongs
here so it is visible at the call site; anything derivable from the circuit is
derived. -/
structure Config where
  /-- The registry field to emit. `Analyze` rejects a circuit whose prime is not
  `field.prime`, so a wrong choice here is a compile error, not silently wrong
  arithmetic. -/
  field : FieldSpec
deriving Repr

end LLZK
