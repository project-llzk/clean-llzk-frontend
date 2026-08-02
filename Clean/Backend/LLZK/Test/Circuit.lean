import Clean.Backend.LLZK.WitnessCheck
import Clean.Backend.LLZK.Examples
import Clean.Gadgets.IsZeroField

/-!
# Golden tests for the whole pipeline

Pins the exact LLZK text the backend produces for each accepted example, and the
exact diagnostics it produces for each rejected one.

Gate G2 is the accepted goldens; gate G8 is the rejected ones. Neither says
anything about whether `llzk-opt` accepts the text — that is G3/G4, and
`scripts/llzk/e2e.sh` runs it over every artifact in the corpus.

## What a golden establishes, and how to refresh one

**A golden detects drift, not error.** The expected text is the emitter's own
output, so it cannot tell that the text was right to begin with — only that a
change to it was reviewed. What makes it more than a snapshot is that the same
text goes through G3, G4 and G5–G7, which are independent of this file. R5e
raised this; `doc/llzk/GAPS.md` records it alongside the other boundaries.

To refresh one after an intended emitter change: run
`lake env lean --run Clean/Backend/LLZK/EmitMain.lean .lake/llzk` and splice the
artifact's text into the `#guard_msgs` docstring, or paste what the build reports
as the mismatch. Deliberately a manual splice and not a script: this file also
holds hand-written rejection fixtures and prose, and a regenerate-the-whole-file
tool — which is how these goldens were first produced — would silently discard
them. A diff that has to be reviewed is the point of the gate.

The accepted circuits live in `Clean/Backend/LLZK/Examples.lean`, shared with the
corpus. The rejected ones live *here*: they are not examples of anything the
library should ship, and having them in a module `Clean.lean` imports meant
deliberately-broken circuits were part of the library (R2 §E6).

## Coverage of the rejection paths

R2-07 found fixture coverage of about a third of the rejection paths. Every one
is now pinned below, in this order:

| Path | Fixture |
|---|---|
| configured field is not the circuit's | `mersenne` on `multiply` |
| natural divisor is `0` | `moduloByZero` |
| natural divisor is at or above the prime | `divideByPrime` |
| an unrecognized `FExpr` (`ite`) | `Gadgets.IsZeroField` |
| an unrecognized `NExpr` under `ofNat` | `shiftWitness` |
| a `.native` witness closure | `nativeWitness` |
| witness `let`-steps | `letStepWitness` |
| a `mapRange` witness output | `mapRangeWitness` |
| an `append` witness output | `appendWitness` |
| a witness cell reading its own block | `selfReadingBlock` |
| an expression naming an undefined circuit variable | `undefinedVariable` |
| a `.interact` operation | `interaction` |
| a lookup into an unregistered table | `withoutBytes` on `Addition8FullCarry` |
| a lookup whose arity disagrees with the registry | `arityMismatch` |
| a malformed registry entry (name, arity, row width) | `malformedTable` |
| a table name colliding with the component | `collidingTable` |
| a table row value at or above the prime | `unreducedTable` |
| an empty table | `emptyTable` |
| a duplicated table name | `duplicateTables` |
| a field that is not in `FieldSpec.registry` | `unregisteredField` |
| a divisor of `0` reaching `lower` unrecognized | `recognizedWith #[.umod _ 0]` |
| a divisor at or above the prime, likewise | `recognizedWith #[.umod _ (p+5)]` |
| a constant at or above the prime, in an output | `recognizedWith #[] #[.const (p+7)]` |
| the same, in an assertion | the `asserts` guard below |

The last five are R5's. The registry-membership branch was R4b-1's own repair and
had no fixture; the other four are D011's side conditions, which were enforced by
the *recognizer* and so did not hold of `lowerRecognized`, the door the six
`Square_*` corpus entries go through.

One path listed in R2-07 has no fixture because it is unreachable, not because it
is untested: `recognizeLookup`'s "lookup queries n values" branch. `Lookup.entry`
is a `Vector (Expression F) table.arity`, and `diagnoseRegistry` has already
rejected every registered arity other than 1, so a lookup that gets past the
arity comparison necessarily queries exactly one value. The branch stays as a
total match Lean requires; it is commented as such in `Analyze.lean`.
-/

namespace LLZK.Test.Circuit

open LLZK.Examples

/-! ## Accepted -/

/--
info: module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  struct.def @Main {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v1: !felt.type<"babybear"> {function.arg_name = "arg1"}
    ) -> !struct.type<@Main> {
      %v2 = struct.new : !struct.type<@Main>
      %v3 = felt.mul %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v2[@w0] = %v3 : !struct.type<@Main>, !felt.type<"babybear">
      struct.writem %v2[@out0] = %v3 : !struct.type<@Main>, !felt.type<"babybear">
      function.return %v2 : !struct.type<@Main>
    }

    function.def @constrain(
      %v0: !struct.type<@Main>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v2: !felt.type<"babybear"> {function.arg_name = "arg1"}
    ) {
      %v3 = struct.readm %v0[@w0] : !struct.type<@Main>, !felt.type<"babybear">
      %v4 = felt.const 0 : !felt.type<"babybear">
      %v5 = felt.const 2013265920 : !felt.type<"babybear">
      %v6 = felt.mul %v1, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v7 = felt.mul %v5, %v6 : !felt.type<"babybear">, !felt.type<"babybear">
      %v8 = felt.add %v3, %v7 : !felt.type<"babybear">, !felt.type<"babybear">
      constrain.eq %v8, %v4 : !felt.type<"babybear">, !felt.type<"babybear">
      %v9 = struct.readm %v0[@out0] : !struct.type<@Main>, !felt.type<"babybear">
      constrain.eq %v9, %v3 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit babybear multiply)

/--
info: module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  struct.def @Main {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @w1 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}
    struct.member @out1 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) -> !struct.type<@Main> attributes {function.allow_non_native_field_ops} {
      %v1 = struct.new : !struct.type<@Main>
      %v2 = felt.const 256 : !felt.type<"babybear">
      %v3 = felt.umod %v0, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v1[@w0] = %v3 : !struct.type<@Main>, !felt.type<"babybear">
      %v4 = felt.const 256 : !felt.type<"babybear">
      %v5 = felt.uintdiv %v0, %v4 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v1[@w1] = %v5 : !struct.type<@Main>, !felt.type<"babybear">
      struct.writem %v1[@out0] = %v3 : !struct.type<@Main>, !felt.type<"babybear">
      struct.writem %v1[@out1] = %v5 : !struct.type<@Main>, !felt.type<"babybear">
      function.return %v1 : !struct.type<@Main>
    }

    function.def @constrain(
      %v0: !struct.type<@Main>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) {
      %v2 = struct.readm %v0[@w0] : !struct.type<@Main>, !felt.type<"babybear">
      %v3 = struct.readm %v0[@w1] : !struct.type<@Main>, !felt.type<"babybear">
      %v4 = struct.readm %v0[@out0] : !struct.type<@Main>, !felt.type<"babybear">
      constrain.eq %v4, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v5 = struct.readm %v0[@out1] : !struct.type<@Main>, !felt.type<"babybear">
      constrain.eq %v5, %v3 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit babybear decompose)

/--
info: module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  struct.def @Main {
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) -> !struct.type<@Main> {
      %v1 = struct.new : !struct.type<@Main>
      struct.writem %v1[@out0] = %v0 : !struct.type<@Main>, !felt.type<"babybear">
      function.return %v1 : !struct.type<@Main>
    }

    function.def @constrain(
      %v0: !struct.type<@Main>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) {
      %v2 = struct.readm %v0[@out0] : !struct.type<@Main>, !felt.type<"babybear">
      constrain.eq %v2, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit babybear passthrough)

/--
info: module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  struct.def @Main {
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) -> !struct.type<@Main> {
      %v1 = struct.new : !struct.type<@Main>
      %v2 = felt.const 7 : !felt.type<"babybear">
      struct.writem %v1[@out0] = %v2 : !struct.type<@Main>, !felt.type<"babybear">
      function.return %v1 : !struct.type<@Main>
    }

    function.def @constrain(
      %v0: !struct.type<@Main>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) {
      %v2 = struct.readm %v0[@out0] : !struct.type<@Main>, !felt.type<"babybear">
      %v3 = felt.const 7 : !felt.type<"babybear">
      constrain.eq %v2, %v3 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit babybear constOut)

/--
info: module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  global.def const @Bytes : !array.type<256 x !felt.type<"babybear">> = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]

  struct.def @Main {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @w1 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}
    struct.member @out1 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v1: !felt.type<"babybear"> {function.arg_name = "arg1"},
      %v2: !felt.type<"babybear"> {function.arg_name = "arg2"}
    ) -> !struct.type<@Main> attributes {function.allow_non_native_field_ops} {
      %v3 = struct.new : !struct.type<@Main>
      %v4 = felt.add %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v5 = felt.add %v4, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v6 = felt.const 256 : !felt.type<"babybear">
      %v7 = felt.umod %v5, %v6 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v3[@w0] = %v7 : !struct.type<@Main>, !felt.type<"babybear">
      %v8 = felt.add %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v9 = felt.add %v8, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v10 = felt.const 256 : !felt.type<"babybear">
      %v11 = felt.uintdiv %v9, %v10 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v3[@w1] = %v11 : !struct.type<@Main>, !felt.type<"babybear">
      struct.writem %v3[@out0] = %v7 : !struct.type<@Main>, !felt.type<"babybear">
      struct.writem %v3[@out1] = %v11 : !struct.type<@Main>, !felt.type<"babybear">
      function.return %v3 : !struct.type<@Main>
    }

    function.def @constrain(
      %v0: !struct.type<@Main>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v2: !felt.type<"babybear"> {function.arg_name = "arg1"},
      %v3: !felt.type<"babybear"> {function.arg_name = "arg2"}
    ) {
      %v4 = struct.readm %v0[@w0] : !struct.type<@Main>, !felt.type<"babybear">
      %v5 = struct.readm %v0[@w1] : !struct.type<@Main>, !felt.type<"babybear">
      %v6 = global.read @Bytes : !array.type<256 x !felt.type<"babybear">>
      constrain.in %v6, %v4 : !array.type<256 x !felt.type<"babybear">>, !felt.type<"babybear">
      %v7 = felt.const 0 : !felt.type<"babybear">
      %v8 = felt.const 2013265920 : !felt.type<"babybear">
      %v9 = felt.const 1 : !felt.type<"babybear">
      %v10 = felt.mul %v8, %v9 : !felt.type<"babybear">, !felt.type<"babybear">
      %v11 = felt.add %v5, %v10 : !felt.type<"babybear">, !felt.type<"babybear">
      %v12 = felt.mul %v5, %v11 : !felt.type<"babybear">, !felt.type<"babybear">
      constrain.eq %v12, %v7 : !felt.type<"babybear">, !felt.type<"babybear">
      %v13 = felt.add %v1, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v14 = felt.add %v13, %v3 : !felt.type<"babybear">, !felt.type<"babybear">
      %v15 = felt.const 2013265920 : !felt.type<"babybear">
      %v16 = felt.mul %v15, %v4 : !felt.type<"babybear">, !felt.type<"babybear">
      %v17 = felt.add %v14, %v16 : !felt.type<"babybear">, !felt.type<"babybear">
      %v18 = felt.const 2013265920 : !felt.type<"babybear">
      %v19 = felt.const 256 : !felt.type<"babybear">
      %v20 = felt.mul %v5, %v19 : !felt.type<"babybear">, !felt.type<"babybear">
      %v21 = felt.mul %v18, %v20 : !felt.type<"babybear">, !felt.type<"babybear">
      %v22 = felt.add %v17, %v21 : !felt.type<"babybear">, !felt.type<"babybear">
      constrain.eq %v22, %v7 : !felt.type<"babybear">, !felt.type<"babybear">
      %v23 = struct.readm %v0[@out0] : !struct.type<@Main>, !felt.type<"babybear">
      constrain.eq %v23, %v4 : !felt.type<"babybear">, !felt.type<"babybear">
      %v24 = struct.readm %v0[@out1] : !struct.type<@Main>, !felt.type<"babybear">
      constrain.eq %v24, %v5 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit withBytes (Gadgets.Addition8FullCarry.circuit (p := pBabybear)))

/-! ## Lookup tables

`ExportTable.ofStatic` derives rows from a `StaticTable`, so they cannot disagree
with the table's own `row` function. Clean's `ByteTable` inlines its
`StaticTable` into `Table.fromStatic`, which discards it, so the byte rows are
written out instead — see the note on `byteTable` and D012. -/

/-- A `StaticTable` whose rows `ofStatic` derives. `Spec` is stated as
containment so that `contains_iff` is `Iff.rfl`: this fixture exists to test the
derivation, not to say anything about the table. -/
def tinyStatic : StaticTable (F pBabybear) field where
  name := "Tiny"
  length := 4
  row i := (i.val : F pBabybear)
  index x := x.val
  Spec t := ∃ i : Fin 4, t = (i.val : F pBabybear)
  contains_iff _ := Iff.rfl

#guard (ExportTable.ofStatic tinyStatic).name == "Tiny"
#guard (ExportTable.ofStatic tinyStatic).arity == 1
#guard (ExportTable.ofStatic tinyStatic).rows == #[#[0], #[1], #[2], #[3]]

/-! ## Rejected (gate G8)

Every construct outside the Stage-1 subset must be refused *before* any LLZK text
exists, and the refusal must say what was hit.

### Circuits

Four rejected circuits, written as `FormalCircuit`s because the constructs they
carry are ones Clean's authoring surface produces naturally. -/

/-- Rejected: Lean's `Nat` modulo by zero is total, LLZK's is not. -/
def moduloByZero : FormalCircuit (F pBabybear) field Parts where
  main x := do
    let lo ← witness ((x.val % 0).toField)
    let hi ← witness ((x.val / 256).toField)
    return { lo, hi }
  Assumptions _ := True
  Spec _ _ := True
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

/-- Rejected: `felt.const` would reduce a divisor at or above the prime. -/
def divideByPrime : FormalCircuit (F pBabybear) field Parts where
  main x := do
    let lo ← witness ((x.val % 256).toField)
    let hi ← witness ((x.val / pBabybear).toField)
    return { lo, hi }
  Assumptions _ := True
  Spec _ _ := True
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

def mersenne : CertifiedConfig (F pBabybear) := .forField .mersenne31

def withoutBytes : CertifiedConfig (F pBabybear) := .forField .babybear

/-! ### Hand-built sources

The remaining rejection paths are reached by constructs Clean's authoring surface
does not produce, or produces only inside a gadget that would fail for an earlier
reason. Building the `Source` directly is what makes each of them a one-line
fixture that names exactly the path it covers. -/

/-- A flattened circuit, built directly rather than by walking a `FormalCircuit`. -/
private def source (inputSize : Nat) (operations : List (FlatOperation (F pBabybear)))
    (outputs : Array (Expression (F pBabybear)) := #[]) : Source (F pBabybear) :=
  { inputSize, operations, outputs }

/-- A `RawTable` with trivial predicates: these fixtures test name and arity
resolution, which is all the backend reads from a table. -/
private def rawTable (name : String) (arity : Nat) : RawTable (F pBabybear) where
  name := name
  arity := arity
  Contains _ _ := True
  Soundness _ _ := True
  Completeness _ _ := True
  imply_soundness _ _ _ := trivial
  implied_by_completeness _ _ _ := trivial

private def rawChannel : RawChannel (F pBabybear) where
  name := "Bus"
  arity := 1
  Guarantees _ _ _ := True
  Requirements _ _ _ := True

/-- A natural shift is not one of the two recognized `ofNat` shapes. The
diagnostic names the `NExpr` constructor rather than falling back to a generic
message, which was one of the two places `describeFExpr`'s stated principle was
not followed (R2 §D1). -/
private def shiftWitness : Source (F pBabybear) :=
  source 1 [.witness 1 (.ir [] (.lit #v[.ofNat (.shiftR (.val (.expr (.var ⟨0⟩))) (.const 8))]))]

/-- A native witness closure: the one thing Clean's own `#assert_exportable`
also rejects. -/
private def nativeWitness : Source (F pBabybear) :=
  source 1 [.witness 1 (.native fun _ => .replicate 1 0)]

/-- A witness program with a `let`-step. -/
private def letStepWitness : Source (F pBabybear) :=
  source 1 [.witness 1 (.ir [.letF (.const 0)] (.lit #v[.localVar 0]))]

/-- A witness output built by a `mapRange` loop rather than a literal vector. -/
private def mapRangeWitness : Source (F pBabybear) :=
  source 1 [.witness 2 (.ir [] (.mapRange 2 (.const 0)))]

/-- A witness output built by appending two vectors. -/
private def appendWitness : Source (F pBabybear) :=
  source 1 [.witness 2 (.ir [] (.append (.lit #v[.const 0]) (.lit #v[.const 0])))]

/-- Cell 1 of a two-cell block reads circuit variable 1, which is cell 0 of the
same block. Clean evaluates the whole block against the environment before it, so
that read is `0` there; the emitted `@compute` would read the computed value.
This is R2-03, and it is the only §A refutation the review found. -/
private def selfReadingBlock : Source (F pBabybear) :=
  source 1 [.witness 2 (.ir [] (.lit #v[.const 0, .expr (.var ⟨1⟩)]))]

/-- An output naming a circuit variable no input or witness defines. This is the
lowering's one genuine failure — `FieldExpr.lower`'s only `throw` — and it was
the untested one. -/
private def undefinedVariable : Source (F pBabybear) :=
  source 1 [] #[.var ⟨3⟩]

/-- A channel interaction, which is outside the scalar circuit subset. -/
private def interaction : Source (F pBabybear) :=
  source 1 [.interact { channel := rawChannel, mult := .const 1, msg := #v[.const 0],
                        assumeGuarantees := false }]

/-- A lookup whose table declares arity 2 while the registry entry has arity 1. -/
private def arityMismatch : Source (F pBabybear) :=
  source 1 [.lookup { table := rawTable "Bytes" 2, entry := #v[.const 0, .const 0] }]

/-- A lookup that resolves, used to show the registry diagnostics below fire
before any lowering. -/
private def oneLookup : Source (F pBabybear) :=
  source 1 [.lookup { table := rawTable "Bytes" 1, entry := #v[.const 0] }]

/-! ### The registry diagnostics, which need an *uncertified* configuration

Since S24 the supported entry points take a `CertifiedConfig`, and none of the
registries below can be written as one: `CertifiedTable` demands an
`ExportTable.Certifies` proof, and these tables are malformed on purpose. That is
the closure working, so these fixtures drop to `compileSource` — public,
G12-confined to `Test/` and the four backend modules, and *before* the point
where a certificate would be relevant. The diagnostics under test are `recognize`'s,
which run identically on both paths; what is skipped is G9, which has nothing to
say about a compilation that fails. -/
private def emitUncertified (cfg : Config) (src : Source (F pBabybear)) : String :=
  renderResult (compileSource cfg src)

private def malformedTable : Config :=
  .unsafeWithTables .babybear #[{ name := "not a symbol", arity := 2, rows := #[#[0]] }]

/-- A table named `Main` collides with the component in the module's symbol
table: `llzk-opt` reports "symbol @Main references a 'global.def' but expected a
'struct.def'". R2 control S2. -/
private def collidingTable : Config :=
  .unsafeWithTables .babybear #[{ name := "Main", arity := 1, rows := #[#[0]] }]

/-- Row values at or above the prime are not canonical representatives; emitting
them would make the lookup table a different set of rows. R2-02. -/
private def unreducedTable : Config :=
  .unsafeWithTables .babybear #[{ name := "Bytes", arity := 1, rows := #[#[0], #[2013265921]] }]

private def emptyTable : Config :=
  .unsafeWithTables .babybear #[{ name := "Bytes", arity := 1, rows := #[] }]

private def duplicateTables : Config :=
  .unsafeWithTables .babybear
    #[{ name := "Bytes", arity := 1, rows := #[#[0]] },
      { name := "Bytes", arity := 1, rows := #[#[1]] }]

/-- A field that is not in LLZK's registry. `FieldSpec` is a public structure, so
this is a pair anyone can write down, and `{ name := "bn254", prime := <babybear
prime> }` was R4b-1: a babybear circuit emitted as `!felt.type<"bn254">`, accepted
by `llzk-opt`, both witgen backends, both halves of G9 and G10.

The repair was a registry-membership check. R5 pointed out that the repair itself
had no fixture — the one branch this project most needed to stay working was the
one nothing exercised. -/
private def unregisteredField : Config :=
  .forField { name := "babybear-ish", prime := pBabybear }

/-! ### The diagnostics -/

-- mersenne on multiply: a configured field whose prime is not the circuit's is a
-- compile error, not arithmetic silently performed in the wrong field
/--
info: compilation failed:
field: configured field 'mersenne31' has prime 2147483647, but the circuit's field has 2013265921 elements
-/
#guard_msgs in
#eval IO.print (emit mersenne multiply)

/--
info: compilation failed:
operation 0 (witness): witness modulo has divisor 0; Lean's natural modulo by zero is total but LLZK's is not, so this shape is refused
-/
#guard_msgs in
#eval IO.print (emit babybear moduloByZero)

/--
info: compilation failed:
operation 1 (witness): witness division has divisor 2013265921, which is not below the field prime 2013265921; `felt.const` would reduce it modulo the prime
-/
#guard_msgs in
#eval IO.print (emit babybear divideByPrime)

/--
info: compilation failed:
operation 0 (witness): unsupported witness expression: `ite` (a conditional); it needs `scf.if`, which is a later increment
-/
#guard_msgs in
#eval IO.print (emit babybear (Gadgets.IsZeroField.circuit (F := F pBabybear)))

/--
info: compilation failed:
operation 0 (witness): unsupported witness expression: `ofNat` applied to `shiftR` (a right shift); only the two recognized division/modulo shapes are lowered
-/
#guard_msgs in
#eval IO.print (emitSource babybear shiftWitness)

/--
info: compilation failed:
operation 0 (witness): witness is a native Lean closure, which cannot be exported; port it to the witness IR (see doc/witgen-authoring.md)
-/
#guard_msgs in
#eval IO.print (emitSource babybear nativeWitness)

/--
info: compilation failed:
operation 0 (witness): witness program starts with `letF` (a field-sorted `let`-step) and has 1 `let`-step(s) in total; only step-free programs are supported
-/
#guard_msgs in
#eval IO.print (emitSource babybear letStepWitness)

/--
info: compilation failed:
operation 0 (witness): witness output is a `mapRange` loop; only literal output vectors are supported (unrolling or `scf.for` is a later increment)
-/
#guard_msgs in
#eval IO.print (emitSource babybear mapRangeWitness)

/--
info: compilation failed:
operation 0 (witness): witness output is an `append`; only literal output vectors are supported
-/
#guard_msgs in
#eval IO.print (emitSource babybear appendWitness)

/--
info: compilation failed:
operation 0 (witness): cell 1 reads circuit variable 1, which this same witness block allocates (the block starts at variable 1); Clean evaluates a block against the environment *before* it, so that read is 0 there and would be the computed value here. Split the block, or read only inputs and cells from earlier blocks
-/
#guard_msgs in
#eval IO.print (emitSource babybear selfReadingBlock)

/--
info: compilation failed:
output 0: expression reads circuit variable 3, which no input or earlier witness defines; variables 0 to 0 are in scope here
-/
#guard_msgs in
#eval IO.print (emitSource babybear undefinedVariable)

/--
info: compilation failed:
operation 0 (interact): interaction on channel 'Bus'; channel interactions are outside the scalar circuit subset
-/
#guard_msgs in
#eval IO.print (emitSource babybear interaction)

/--
info: compilation failed:
operation 1 (lookup): lookup into table 'Bytes', which is not in the export registry; add its rows to `Config.tables` (`ExportTable.ofStatic` derives them from a `StaticTable`)
-/
#guard_msgs in
#eval IO.print (emit withoutBytes (Gadgets.Addition8FullCarry.circuit (p := pBabybear)))

/--
info: compilation failed:
operation 0 (lookup): lookup into table 'Bytes' has arity 2 but the registered table has arity 1
-/
#guard_msgs in
#eval IO.print (emitSource withBytes arityMismatch)

/--
info: compilation failed:
table 'not a symbol': name is not a legal MLIR symbol; it must start with a letter or underscore and contain only letters, digits and underscores
table 'not a symbol': arity is 2; only single-column tables are supported, because a wider one needs an `array.new` query and a multi-dimensional `constrain.in`
table 'not a symbol': row 0 has 1 value(s) but the arity is 2
-/
#guard_msgs in
#eval IO.print (emitUncertified malformedTable oneLookup)

/--
info: compilation failed:
table 'Main': has the same name as the component; the module's symbol table cannot hold a `global.def` and a `struct.def` called 'Main'
-/
#guard_msgs in
#eval IO.print (emitUncertified collidingTable oneLookup)

/--
info: compilation failed:
table 'Bytes': row value 2013265921 is not below the field prime 2013265921; it is not a canonical representative and `felt.const` would reduce it, so the emitted table would be a different set of rows
-/
#guard_msgs in
#eval IO.print (emitUncertified unreducedTable oneLookup)

/--
info: compilation failed:
table 'Bytes': has no rows; an empty table makes every lookup unsatisfiable, which is never intended
-/
#guard_msgs in
#eval IO.print (emitUncertified emptyTable oneLookup)

/--
info: compilation failed:
table 'Bytes': is registered more than once; a lookup could not be resolved unambiguously
-/
#guard_msgs in
#eval IO.print (emitUncertified duplicateTables oneLookup)

/--
info: compilation failed:
field: configured field 'babybear-ish' with prime 2013265921 is not an entry of `FieldSpec.registry`; LLZK owns the prime for a field name, so a pair it does not know would be emitted as `!felt.type<"babybear-ish">` and interpreted in whatever field LLZK has under that name
-/
#guard_msgs in
#eval IO.print (emitUncertified unregisteredField (Compilable.source multiply))

/-! ## D011's side conditions hold of every lowering, not just recognized ones

`Witness.ofFExpr` checks the divisor conditions, so `recognize`'s output always
satisfies them — and D011 stated them as though that settled it. It did not:
`Recognized` is public and `lowerRecognized` takes one built by hand, which is
how the six `Square_*` registry entries are built. R5c drove two modules out
through that door, both with an empty diagnostic array:

* a divisor of `0`, which `llzk-opt` parses, verifies, round-trips *and*
  product-programs without complaint, and which `llzk-witgen` then traps on;
* a divisor of `p + 5`, emitted as `felt.const 2013265926`, which LLZK reduces to
  `5` — so the module silently computes `7 % 5 = 2` where the author wrote
  `7 % (p + 5) = 7`, on both backends, with every static gate green.

The check now sits inside the private `lower`, below both doors. -/

private def recognizedWith (witnesses outputs : Array FieldExpr) : Recognized :=
  { inputSize := 1, witnesses, asserts := #[], lookups := #[], tables := #[], outputs }

private def viaRecognized (r : Recognized) : String :=
  renderResult (lowerRecognized (.forField .babybear) r)

-- Baseline: a well-formed divisor still lowers, so the guards below are not red
-- for some unrelated reason.
#guard (lowerRecognized (.forField .babybear)
  (recognizedWith #[.umod (.var 0) 256] #[.var 1])).toOption.isSome

/--
info: compilation failed:
witness cell 0: witness modulo has divisor 0; Lean's natural modulo by zero is total but LLZK's is not, so this shape is refused
-/
#guard_msgs in
#eval IO.print (viaRecognized (recognizedWith #[.umod (.var 0) 0] #[.var 1]))

/--
info: compilation failed:
witness cell 0: witness division has divisor 0; Lean's natural division by zero is total but LLZK's is not, so this shape is refused
-/
#guard_msgs in
#eval IO.print (viaRecognized (recognizedWith #[.uintdiv (.var 0) 0] #[.var 1]))

/--
info: compilation failed:
witness cell 0: witness modulo has divisor 2013265926, which is not below the field prime 2013265921; `felt.const` would reduce it modulo the prime
-/
#guard_msgs in
#eval IO.print (viaRecognized (recognizedWith #[.umod (.var 0) (pBabybear + 5)] #[.var 1]))

-- A constant at or above the prime, which `felt.const` would reduce. Not one of
-- R5c's two, but the same defect in the third expression position -- and
-- `outputs` reaches the renderer through `@constrain`, where no witgen backend
-- would ever execute it.
/--
info: compilation failed:
output 0: constant 2013265928 is not below the field prime 2013265921; `felt.const` reduces its operand modulo the prime, so the emitted module would not denote what this expression says
-/
#guard_msgs in
#eval IO.print (viaRecognized (recognizedWith #[] #[.const (pBabybear + 7)]))

-- And in an assertion, the fourth position.
/--
info: compilation failed:
assertion 0: constant 2013265928 is not below the field prime 2013265921; `felt.const` reduces its operand modulo the prime, so the emitted module would not denote what this expression says
-/
#guard_msgs in
#eval IO.print (renderResult (lowerRecognized (.forField .babybear)
  { inputSize := 1, witnesses := #[], asserts := #[.const (pBabybear + 7)],
    lookups := #[], tables := #[], outputs := #[] }))

end LLZK.Test.Circuit
