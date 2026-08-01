import Clean.Backend.LLZK.Print

/-!
# Golden test for the LLZK renderer

Renders a module that uses every constructor of the backend IR and pins the exact
output. This is gate G2 at the renderer level: any change to the concrete syntax
this backend emits has to show up here as a reviewed diff.

The module is deliberately artificial. It is not a lowering of any Clean circuit
— walking a circuit is `Circuit.lean`'s job — but it is valid LLZK, so
`scripts/llzk/e2e.sh` can also feed it to `llzk-opt` as a syntax check that does
not depend on any gadget.
-/

namespace LLZK.Test.Print

private def felt : Ty := .felt "babybear"
private def bytes : Ty := .array 4 felt
private def demo : Ty := .struct "Demo"
private def empty : Ty := .struct "Empty"

/-- Read one of the input values a component builder hands the body. The builders
pass inputs as an array, so a test that asks for a position the specification did
not declare is a test bug; it surfaces as a diagnostic rather than a panic. -/
private def input (args : Array Value) (i : Nat) : Except Diagnostic Value :=
  match args[i]? with
  | some v => .ok v
  | none => .error { context := "test", message := s!"no input {i}" }

/-- `@Demo`'s `@compute`: exercises every binary operation, `felt.const`,
`struct.writem`, a named and an unnamed parameter. Using `felt.uintdiv`/
`felt.umod` must make the rendered signature carry
`function.allow_non_native_field_ops`. -/
private def demoCompute : Except Diagnostic Func :=
  Builder.computeFunction demo
    #[{ ty := felt, argName := "lhs" }, { ty := felt }]
    fun self args => do
      let lhs ← input args 0
      let rhs ← input args 1
      let sum ← Builder.feltBin .add lhs rhs felt
      let diff ← Builder.feltBin .sub sum lhs felt
      let prod ← Builder.feltBin .mul diff rhs felt
      let quot ← Builder.feltBin .div prod lhs felt
      let c256 ← Builder.feltConst 256 felt
      let q ← Builder.feltBin .uintdiv quot c256 felt
      let r ← Builder.feltBin .umod quot c256 felt
      Builder.writeMember self demo "w0" q felt
      Builder.writeMember self demo "out0" r felt

/-- `@Demo`'s `@constrain`: exercises `struct.readm`, `global.read`,
`constrain.eq` and `constrain.in`. -/
private def demoConstrain : Except Diagnostic Func :=
  Builder.constrainFunction demo #[{ ty := felt, argName := "lhs" }]
    fun self args => do
      let lhs ← input args 0
      let w0 ← Builder.readMember self demo "w0" felt
      let out0 ← Builder.readMember self demo "out0" felt
      let table ← Builder.globalRead "Bytes" bytes
      Builder.constrainIn table bytes w0 felt
      Builder.constrainEq out0 lhs felt

/-- A component with no members and a parameterless `@compute`, so the renderer's
empty-parameter and empty-member paths are covered. -/
private def emptyStruct : Except Diagnostic StructDef := do
  return {
    name := "Empty"
    members := #[]
    compute := ← Builder.computeFunction empty #[] fun _ _ => pure ()
    constrain := ← Builder.constrainFunction empty #[] fun _ _ => pure () }

private def demoStruct : Except Diagnostic StructDef := do
  return {
    name := "Demo"
    members := #[
      { name := "w0", ty := felt, visibility := .signal },
      { name := "out0", ty := felt, visibility := .pub }]
    compute := ← demoCompute
    constrain := ← demoConstrain }

private def demoModule : Except Diagnostic Module := do
  return {
    main := "Demo"
    globals := #[{ name := "Bytes", elemTy := felt, values := #[0, 1, 2, 3] }]
    structs := #[← demoStruct, ← emptyStruct] }

/--
info: module attributes {llzk.lang, llzk.main = !struct.type<@Demo>} {
  global.def const @Bytes : !array.type<4 x !felt.type<"babybear">> = [0, 1, 2, 3]

  struct.def @Demo {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "lhs"},
      %v1: !felt.type<"babybear">
    ) -> !struct.type<@Demo> attributes {function.allow_non_native_field_ops} {
      %v2 = struct.new : !struct.type<@Demo>
      %v3 = felt.add %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v4 = felt.sub %v3, %v0 : !felt.type<"babybear">, !felt.type<"babybear">
      %v5 = felt.mul %v4, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v6 = felt.div %v5, %v0 : !felt.type<"babybear">, !felt.type<"babybear">
      %v7 = felt.const 256 : !felt.type<"babybear">
      %v8 = felt.uintdiv %v6, %v7 : !felt.type<"babybear">, !felt.type<"babybear">
      %v9 = felt.umod %v6, %v7 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v2[@w0] = %v8 : !struct.type<@Demo>, !felt.type<"babybear">
      struct.writem %v2[@out0] = %v9 : !struct.type<@Demo>, !felt.type<"babybear">
      function.return %v2 : !struct.type<@Demo>
    }

    function.def @constrain(
      %v0: !struct.type<@Demo>,
      %v1: !felt.type<"babybear"> {function.arg_name = "lhs"}
    ) {
      %v2 = struct.readm %v0[@w0] : !struct.type<@Demo>, !felt.type<"babybear">
      %v3 = struct.readm %v0[@out0] : !struct.type<@Demo>, !felt.type<"babybear">
      %v4 = global.read @Bytes : !array.type<4 x !felt.type<"babybear">>
      constrain.in %v4, %v2 : !array.type<4 x !felt.type<"babybear">>, !felt.type<"babybear">
      constrain.eq %v3, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }

  struct.def @Empty {
    function.def @compute() -> !struct.type<@Empty> {
      %v0 = struct.new : !struct.type<@Empty>
      function.return %v0 : !struct.type<@Empty>
    }

    function.def @constrain(
      %v0: !struct.type<@Empty>
    ) {
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (renderResult (demoModule.mapError (#[·])))

end LLZK.Test.Print
