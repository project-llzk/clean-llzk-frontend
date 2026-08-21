import Clean.Backend.LLZK.RendererFixture

/-!
# Golden tests for the LLZK renderer

Pins the exact output of the two renderer fixtures in
`Clean/Backend/LLZK/RendererFixture.lean`, which between them use every
constructor of the backend IR. This is gate G2 at the renderer level: any change
to the concrete syntax this backend emits has to show up here as a reviewed diff.

Unlike before S11, the text pinned here is also checked by a tool.
`scripts/llzk/e2e.sh` writes both fixtures to `.lake/llzk/syntax/` and runs
`llzk-opt` and `--verify-roundtrip` over them, so a golden that is not valid LLZK
is now a red gate rather than a green one — which is what the previous fixture
was (R2-04).
-/

namespace LLZK.Test.Print

/--
info: module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  global.def const @Bytes : !array.type<4 x !felt.type<"babybear">> = [0, 1, 2, 3]

  struct.def @Main {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "lhs"},
      %v1: !felt.type<"babybear">
    ) -> !struct.type<@Main> attributes {function.allow_non_native_field_ops} {
      %v2 = struct.new : !struct.type<@Main>
      %v3 = felt.add %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v4 = felt.mul %v3, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v5 = felt.const 256 : !felt.type<"babybear">
      %v6 = felt.uintdiv %v4, %v5 : !felt.type<"babybear">, !felt.type<"babybear">
      %v7 = felt.umod %v4, %v5 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v2[@w0] = %v6 : !struct.type<@Main>, !felt.type<"babybear">
      struct.writem %v2[@out0] = %v7 : !struct.type<@Main>, !felt.type<"babybear">
      function.return %v2 : !struct.type<@Main>
    }

    function.def @constrain(
      %v0: !struct.type<@Main>,
      %v1: !felt.type<"babybear"> {function.arg_name = "lhs"},
      %v2: !felt.type<"babybear">
    ) {
      %v3 = struct.readm %v0[@w0] : !struct.type<@Main>, !felt.type<"babybear">
      %v4 = struct.readm %v0[@out0] : !struct.type<@Main>, !felt.type<"babybear">
      %v5 = global.read @Bytes : !array.type<4 x !felt.type<"babybear">>
      constrain.in %v5, %v3 : !array.type<4 x !felt.type<"babybear">>, !felt.type<"babybear">
      constrain.eq %v4, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (renderResult (RendererFixture.demoModule.mapError (#[·])))

/-! The empty-member and empty-parameter paths. `llzk-opt` accepts a component
with no members, a parameterless `@compute` and a `@constrain` with no
constraints; `e2e.sh` is where that is established, not here. -/

/--
info: module attributes {llzk.lang = "clean", llzk.main = !struct.type<@Main>} {
  struct.def @Main {
    function.def @compute() -> !struct.type<@Main> {
      %v0 = struct.new : !struct.type<@Main>
      function.return %v0 : !struct.type<@Main>
    }

    function.def @constrain(
      %v0: !struct.type<@Main>
    ) {
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (renderResult (RendererFixture.emptyModule.mapError (#[·])))

/-! ## A5 — the rendered constraint surface reads back

The three direct parser controls make the concrete grammar visible here rather
than trusting only the renderer's own output. The module controls then pin both
directions a gate needs: the real fixture succeeds, while each mutation R6/R7
showed the LLZK binaries accept is refused by the Lean-side round trip.
-/

#guard RenderCheck.parseStmt
    "%v3 = struct.readm %v0[@w0] : !struct.type<@Main>, !felt.type<\"babybear\">" =
  some (.readMember 3 0 "w0" (.struct "Main") (.felt "babybear"))

#guard RenderCheck.parseStmt
    "constrain.eq %v4, %v1 : !felt.type<\"babybear\">, !felt.type<\"babybear\">" =
  some (.constrainEq 4 1 (.felt "babybear") (.felt "babybear"))

#guard RenderCheck.parseStmt
    "constrain.in %v5, %v3 : !array.type<4 x !felt.type<\"babybear\">>, \
      !felt.type<\"babybear\">" =
  some (.constrainIn 5 3 (.array 4 (.felt "babybear")) (.felt "babybear"))

#guard RenderCheck.parseTy
  "!array.type<2 x !array.type<4 x !felt.type<\"babybear\">>>" =
    some (.array 2 (.array 4 (.felt "babybear")))

private def renderedDemo : Option (Module × String) := do
  let m ← RendererFixture.demoModule.toOption
  let text ← m.render.toOption
  return (m, text)

#guard renderedDemo.isSome

private def rejectsMutation (old replacement : String) : Bool :=
  match renderedDemo with
  | none => false
  | some (m, text) =>
    let changed := text.replace old replacement
    if changed = text then false
    else match RenderCheck.check m changed with | .error _ => true | .ok _ => false

-- R6's same-typed member-alias mutation.
#guard rejectsMutation
  "%v4 = struct.readm %v0[@out0]"
  "%v4 = struct.readm %v0[@w0]"

-- R2's empty/deleted-equation control, reached through the renderer.
#guard rejectsMutation
  "      constrain.eq %v4, %v1 : !felt.type<\"babybear\">, !felt.type<\"babybear\">\n"
  ""

-- A dropped lookup constraint, the third constraint-only statement form.
#guard rejectsMutation
  "      constrain.in %v5, %v3 : !array.type<4 x !felt.type<\"babybear\">>, \
    !felt.type<\"babybear\">\n"
  ""

-- The reader also ties the surface to the `@constrain` function, not merely to
-- the sequence of protected lines somewhere in the module.
#guard rejectsMutation
  "function.def @constrain("
  "function.def @not_constrain("

-- A type-rendering mutation must not share `Ty.render` on both sides of the
-- check. The textual reader reconstructs the original typed AST independently.
#guard rejectsMutation
  "constrain.eq %v4, %v1 : !felt.type<\"babybear\">, !felt.type<\"babybear\">"
  "constrain.eq %v4, %v1 : !felt.type<\"bn254\">, !felt.type<\"bn254\">"

end LLZK.Test.Print
