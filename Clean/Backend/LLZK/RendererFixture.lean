import Clean.Backend.LLZK.Print

/-!
# Renderer fixtures

Two modules built directly against the emitter IR, exercising every constructor
the renderer can be asked to print. They are not lowerings of any Clean circuit —
walking a circuit is `Circuit.lean`'s job — and that is the point: they cover the
renderer independently of any gadget.

They live in the library, not in `Test/`, because `scripts/llzk/e2e.sh` feeds
them to `llzk-opt`. That is the repair for R2-04: the previous fixture was pinned
by a golden and *never* shown to a tool, and it was in fact invalid LLZK —
`@compute` took two parameters and `@constrain` one, which `llzk-opt` rejects.
`Test/Print.lean` still pins the exact text; the harness now also checks that the
text is a module LLZK accepts and round-trips.

`Builder.component` is why the original defect is no longer expressible: one
parameter list goes to both functions.
-/

namespace LLZK.RendererFixture

private def felt : Ty := .felt "babybear"
private def bytes : Ty := .array #[2, 2] felt
private def bytePair : Ty := .array #[2] felt

/-- Read one of the input values the component builder hands the body. The
builder passes inputs as an array, so a fixture that asks for a position the
specification did not declare is a fixture bug; it surfaces as a diagnostic
rather than a panic. -/
private def input (args : Array Value) (i : Nat) : Except Diagnostic Value :=
  match args[i]? with
  | some v => .ok v
  | none => .error { context := "renderer fixture", message := s!"no input {i}" }

/-- A component exercising every statement form and both parameter shapes.

`@compute` uses `felt.const` and every binary operation, including the
non-native natural and bitwise families, so the rendered signature must carry
`function.allow_non_native_field_ops`; it writes both members. `@constrain` reads
both members back, reads a global, and emits both constraint forms. One parameter
is named and one is not. -/
def demoModule : Except Diagnostic Module := do
  let root ← Builder.component (ε := Diagnostic)
    #[{ name := "w0", ty := felt, visibility := .signal },
      { name := "out0", ty := felt, visibility := .pub }]
    #[{ ty := felt, argName := "lhs" }, { ty := felt }]
    (fun self args => do
      let lhs ← input args 0
      let rhs ← input args 1
      let sum ← Builder.feltBin .add lhs rhs felt
      let prod ← Builder.feltBin .mul sum rhs felt
      let c256 ← Builder.feltConst 256 felt
      let quotient ← Builder.feltBin .uintdiv prod c256 felt
      let remainder ← Builder.feltBin .umod prod c256 felt
      let _ ← Builder.feltBin .bitAnd lhs rhs felt
      let _ ← Builder.feltBin .bitOr lhs rhs felt
      let _ ← Builder.feltBin .bitXor lhs rhs felt
      let _ ← Builder.feltBin .shl lhs rhs felt
      let _ ← Builder.feltBin .shr lhs rhs felt
      Builder.writeMember self "w0" quotient felt
      Builder.writeMember self "out0" remainder felt)
    (fun self args => do
      let lhs ← input args 0
      let w0 ← Builder.readMember self "w0" felt
      let out0 ← Builder.readMember self "out0" felt
      let table ← Builder.globalRead "Bytes" bytes
      let row ← Builder.arrayNew #[w0, out0] felt
      Builder.constrainIn table bytes row bytePair
      Builder.constrainEq out0 lhs felt)
  match root with
  | some root =>
      let bytesGlobal : ConstArray :=
        { name := "Bytes", elemTy := felt, arity := 2, rows := #[#[0, 1], #[2, 3]] }
      return { globals := #[bytesGlobal], root }
  | none => .error { context := "renderer fixture", message := "unallocated SSA value" }

/-- A component with no members, no parameters and no constraints, so the
renderer's empty-member and empty-parameter paths are covered — and so that
`llzk-opt` is asked whether it accepts one, which it does. -/
def emptyModule : Except Diagnostic Module := do
  match ← Builder.component (ε := Diagnostic) #[] #[]
      (fun _ _ => pure ()) (fun _ _ => pure ()) with
  | some root => return { globals := #[], root }
  | none => .error { context := "renderer fixture", message := "unallocated SSA value" }

/-- The fixtures the harness materializes, under the names it writes them as. -/
def all : Array (String × Except Diagnostic Module) :=
  #[("Demo", demoModule), ("Empty", emptyModule)]

end LLZK.RendererFixture
