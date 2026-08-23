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

Transcribed from `lib/Util/Field.cpp`, `Field::initKnownFields`, and rechecked at
the accepted LLZK revision `25fb3740ea3465c9129a06289297bb4f0554b7a5` and
upstream main `b5c110d1088e93d6786f66ec1e155be87bae755f` on 2026-08-22. -/
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

end FieldSpec

/-- A lookup table materialized as concrete rows.

Clean's `RawTable` keeps a name, an arity and logical predicates, but
`Table.toRaw` discards a `StaticTable`'s `length` and `row` function. Concrete
rows therefore cannot be recovered by walking a circuit's operations, and the
caller must supply them.

**This is trusted input, but only where it has to be.** The backend checks the
name, the arity, the row widths, that names are unique, that they are legal MLIR
symbols, that none collides with the component name, and that every value is a
canonical representative in `[0, p)` — see `ExportTable.diagnose`, which is the
complete list. It refuses a lookup it cannot resolve.

What it cannot check is that these rows are *the table's* rows:
`RawTable.Contains` is a `Prop`, not something the compiler can evaluate. That,
and nothing else, is D012's trust assumption. Where a `StaticTable` is still in
scope, use `ExportTable.ofStatic`, which derives the rows instead of asserting
them.

Values are canonical representatives in `[0, p)`; a value at or above the prime
is a diagnostic, not a silent reduction. -/
structure ExportTable where
  /-- Must equal the `RawTable.name` of the lookups it resolves. -/
  name : String
  arity : Nat
  /-- One entry per row, each of length `arity`. -/
  rows : Array (Array Nat)
deriving Repr

/-- What the backend needs beyond the circuit itself.

Kept small on purpose. Anything that changes the *meaning* of the output belongs
here so it is visible at the call site; anything derivable from the circuit is
derived. -/
structure Config where
  private mk ::
  /-- The registry field to emit. `Analyze` rejects a circuit whose prime is not
  `field.prime`, so a wrong choice here is a compile error, not silently wrong
  arithmetic. -/
  field : FieldSpec
  /-- Concrete rows for the lookup tables the circuit uses. A lookup with no
  matching entry is a compile error, never a silently dropped constraint. -/
  tables : Array ExportTable
deriving Repr

/-- A configuration with no lookup tables. -/
def Config.forField (field : FieldSpec) : Config := ⟨field, #[]⟩

/-- A configuration whose tables are **asserted, not certified**.

The constructor is private and this is the only public way to put arbitrary,
uncertified rows into a `Config`, so every place that supplies unproved rows says
so by name and `grep` finds all of them. `CertifiedConfig.toConfig` is the other
public table-bearing path; its rows arrive with certificates.
`CertifiedConfig` is what supported checked emission uses: it holds
`CertifiedTable`s, which carry the proof that the rows are the Clean table's, and
since S24 it is what the supported checked entry points in `WitnessCheck.lean`
take — so the proof is a precondition of that emission path rather than
something a wrapper demanded and dropped.

Why this exists at all. The rows cannot be checked by the compiler — that is
D012 — and the negative fixtures must be able to build malformed registries on
purpose. Making the unchecked path *impossible* would delete those fixtures;
making it *quiet* is what allowed R5's X1, where
`{ field := .babybear, tables := #[fatBytes] }` compiled `Addition8FullCarry`
into a module admitting `w0 = 300` with every gate green. So it is loud instead,
and `scripts/llzk/check-confinement.sh` fails if any non-test backend module
names it. -/
def Config.unsafeWithTables (field : FieldSpec) (tables : Array ExportTable) : Config :=
  ⟨field, tables⟩

end LLZK
