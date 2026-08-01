import Clean.Utils.Primes
import Clean.Gadgets.Equality
import Clean.Utils.Tactics.ProvableStructDeriving
import Clean.Utils.Tactics.CircuitProofStart
import Clean.Gadgets.Addition8.Addition8FullCarry
import Clean.Gadgets.IsZeroField
import Clean.Backend.LLZK.Circuit

/-!
# Vertical slice: compiling an assertion-only circuit

Pins the LLZK text the backend produces for a real `FormalCircuit`, and pins the
diagnostics it produces for circuits outside the Stage-1 subset.

`Multiply` is deliberately the smallest circuit that still exercises every part
of the layout: two inputs, one witness cell computed from them, one assertion,
and one output. It has no lookups and no natural arithmetic, so it is inside the
subset this increment accepts.
-/

namespace LLZK.Test.Circuit

/-- Two field elements. -/
structure Inputs (F : Type) where
  x : F
  y : F
deriving ProvableStruct

/-- Witness the product of the inputs and constrain it.

Specialized to Babybear rather than left generic: it is a fixture, and pinning
the field keeps the golden readable. -/
def multiply : FormalCircuit (F pBabybear) Inputs field where
  main input := do
    let ⟨x, y⟩ := input
    let z ← witness ((x * y : Expression (F pBabybear)) : Witgen.FExpr (F pBabybear))
    z === x * y
    return z
  Assumptions _ := True
  Spec input out := out = input.x * input.y
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

private def babybear : Config := { field := .babybear }

/--
info: module attributes {llzk.lang, llzk.main = !struct.type<@Multiply>} {
  struct.def @Multiply {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v1: !felt.type<"babybear"> {function.arg_name = "arg1"}
    ) -> !struct.type<@Multiply> {
      %v2 = struct.new : !struct.type<@Multiply>
      %v3 = felt.mul %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v2[@w0] = %v3 : !struct.type<@Multiply>, !felt.type<"babybear">
      struct.writem %v2[@out0] = %v3 : !struct.type<@Multiply>, !felt.type<"babybear">
      function.return %v2 : !struct.type<@Multiply>
    }

    function.def @constrain(
      %v0: !struct.type<@Multiply>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v2: !felt.type<"babybear"> {function.arg_name = "arg1"}
    ) {
      %v3 = struct.readm %v0[@w0] : !struct.type<@Multiply>, !felt.type<"babybear">
      %v4 = felt.const 0 : !felt.type<"babybear">
      %v5 = felt.const 2013265920 : !felt.type<"babybear">
      %v6 = felt.mul %v1, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v7 = felt.mul %v5, %v6 : !felt.type<"babybear">, !felt.type<"babybear">
      %v8 = felt.add %v3, %v7 : !felt.type<"babybear">, !felt.type<"babybear">
      constrain.eq %v8, %v4 : !felt.type<"babybear">, !felt.type<"babybear">
      %v9 = struct.readm %v0[@out0] : !struct.type<@Multiply>, !felt.type<"babybear">
      constrain.eq %v9, %v3 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit babybear "Multiply" multiply)

/-! ## The two recognized natural division/modulo shapes

`Spec` is `True` for these fixtures on purpose: they exist to exercise the
backend, not to state anything about the circuits. The interesting arithmetic
claim — that `felt.umod`/`felt.uintdiv` on canonical representatives agrees with
Clean's `ofNat (mod (val x) c)` — is argued in `Witness.lean` and is a proof
obligation for P5, not something a golden test can establish. -/

/-- A field element's low byte and the rest. -/
structure Parts (F : Type) where
  lo : F
  hi : F
deriving ProvableStruct

/-- Witness both recognized shapes over the same subexpression. -/
def decompose : FormalCircuit (F pBabybear) field Parts where
  main x := do
    let lo ← witness ((x.val % 256).toField)
    let hi ← witness ((x.val / 256).toField)
    return { lo, hi }
  Assumptions _ := True
  Spec _ _ := True
  soundness := by circuit_proof_all
  completeness := by circuit_proof_all

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

/--
info: module attributes {llzk.lang, llzk.main = !struct.type<@Decompose>} {
  struct.def @Decompose {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @w1 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}
    struct.member @out1 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) -> !struct.type<@Decompose> attributes {function.allow_non_native_field_ops} {
      %v1 = struct.new : !struct.type<@Decompose>
      %v2 = felt.const 256 : !felt.type<"babybear">
      %v3 = felt.umod %v0, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v1[@w0] = %v3 : !struct.type<@Decompose>, !felt.type<"babybear">
      %v4 = felt.const 256 : !felt.type<"babybear">
      %v5 = felt.uintdiv %v0, %v4 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v1[@w1] = %v5 : !struct.type<@Decompose>, !felt.type<"babybear">
      struct.writem %v1[@out0] = %v3 : !struct.type<@Decompose>, !felt.type<"babybear">
      struct.writem %v1[@out1] = %v5 : !struct.type<@Decompose>, !felt.type<"babybear">
      function.return %v1 : !struct.type<@Decompose>
    }

    function.def @constrain(
      %v0: !struct.type<@Decompose>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"}
    ) {
      %v2 = struct.readm %v0[@w0] : !struct.type<@Decompose>, !felt.type<"babybear">
      %v3 = struct.readm %v0[@w1] : !struct.type<@Decompose>, !felt.type<"babybear">
      %v4 = struct.readm %v0[@out0] : !struct.type<@Decompose>, !felt.type<"babybear">
      constrain.eq %v4, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v5 = struct.readm %v0[@out1] : !struct.type<@Decompose>, !felt.type<"babybear">
      constrain.eq %v5, %v3 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit babybear "Decompose" decompose)

/--
info: compilation failed:
operation 0 (witness): witness modulo has divisor 0; Lean's natural modulo by zero is total but LLZK's is not, so this shape is refused
-/
#guard_msgs in
#eval IO.print (emit babybear "ModuloByZero" moduloByZero)

/--
info: compilation failed:
operation 1 (witness): witness division has divisor 2013265921, which is not below the field prime 2013265921; `felt.const` would reduce it modulo the prime
-/
#guard_msgs in
#eval IO.print (emit babybear "DivideByPrime" divideByPrime)

/-! ## Fail-closed behaviour (gate G8)

Every construct outside the Stage-1 subset must be refused *before* any LLZK text
exists, and the refusal must say what was hit. These pin the exact diagnostics.
-/

private def mersenne : Config := { field := .mersenne31 }

-- A configured field whose prime is not the circuit's is a compile error, not
-- arithmetic silently performed in the wrong field.
/--
info: compilation failed:
field: configured field 'mersenne31' has prime 2147483647, but the circuit's field has 2013265921 elements
-/
#guard_msgs in
#eval IO.print (emit mersenne "Multiply" multiply)

-- `Addition8FullCarry` is the Stage-1 target circuit. Its two witness cells are
-- now recognized; the remaining gap is the lookup table registry.
/--
info: compilation failed:
operation 1 (lookup): lookup into table 'Bytes'; lookups need the table export registry, which is a later increment
-/
#guard_msgs in
#eval IO.print (emit babybear "Addition8FullCarry" (Gadgets.Addition8FullCarry.circuit (p := pBabybear)))

-- A witness built from a conditional is refused by name, not by a generic
-- "unsupported" message.
/--
info: compilation failed:
operation 0 (witness): unsupported witness expression: `ite` (a conditional); it needs `scf.if`, which is a later increment
-/
#guard_msgs in
#eval IO.print (emit babybear "IsZeroField" (Gadgets.IsZeroField.circuit (F := F pBabybear)))

end LLZK.Test.Circuit
