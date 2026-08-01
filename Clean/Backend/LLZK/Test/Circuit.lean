import Clean.Backend.LLZK.Examples
import Clean.Gadgets.IsZeroField

/-!
# Golden tests for the whole pipeline

Pins the exact LLZK text the backend produces for each accepted example, and the
exact diagnostics it produces for each rejected one. The circuits themselves live
in `Clean/Backend/LLZK/Examples.lean`, shared with the emitter executable.

Gate G2 is the accepted goldens; gate G8 is the rejected ones. Neither says
anything about whether `llzk-opt` accepts the text — that is G3/G4.
-/

namespace LLZK.Test.Circuit

open LLZK.Examples

/-! ## Accepted -/

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

/-! ## Lookup tables (gate G6 target)

`ExportTable.ofStatic` derives rows from a `StaticTable`, so they cannot disagree
with the table's own `row` function. Clean's `ByteTable` inlines its
`StaticTable` into `Table.fromStatic`, which discards it, so the byte rows here
are written out instead — see the note on `byteTable`. -/

#guard (ExportTable.ofStatic tinyStatic).name == "Tiny"
#guard (ExportTable.ofStatic tinyStatic).arity == 1
#guard (ExportTable.ofStatic tinyStatic).rows == #[#[0], #[1], #[2], #[3]]

/--
info: module attributes {llzk.lang, llzk.main = !struct.type<@Addition8FullCarry>} {
  global.def const @Bytes : !array.type<256 x !felt.type<"babybear">> = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255]

  struct.def @Addition8FullCarry {
    struct.member @w0 : !felt.type<"babybear"> {signal}
    struct.member @w1 : !felt.type<"babybear"> {signal}
    struct.member @out0 : !felt.type<"babybear"> {llzk.pub}
    struct.member @out1 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %v0: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v1: !felt.type<"babybear"> {function.arg_name = "arg1"},
      %v2: !felt.type<"babybear"> {function.arg_name = "arg2"}
    ) -> !struct.type<@Addition8FullCarry> attributes {function.allow_non_native_field_ops} {
      %v3 = struct.new : !struct.type<@Addition8FullCarry>
      %v4 = felt.add %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v5 = felt.add %v4, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v6 = felt.const 256 : !felt.type<"babybear">
      %v7 = felt.umod %v5, %v6 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v3[@w0] = %v7 : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
      %v8 = felt.add %v0, %v1 : !felt.type<"babybear">, !felt.type<"babybear">
      %v9 = felt.add %v8, %v2 : !felt.type<"babybear">, !felt.type<"babybear">
      %v10 = felt.const 256 : !felt.type<"babybear">
      %v11 = felt.uintdiv %v9, %v10 : !felt.type<"babybear">, !felt.type<"babybear">
      struct.writem %v3[@w1] = %v11 : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
      struct.writem %v3[@out0] = %v7 : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
      struct.writem %v3[@out1] = %v11 : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
      function.return %v3 : !struct.type<@Addition8FullCarry>
    }

    function.def @constrain(
      %v0: !struct.type<@Addition8FullCarry>,
      %v1: !felt.type<"babybear"> {function.arg_name = "arg0"},
      %v2: !felt.type<"babybear"> {function.arg_name = "arg1"},
      %v3: !felt.type<"babybear"> {function.arg_name = "arg2"}
    ) {
      %v4 = struct.readm %v0[@w0] : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
      %v5 = struct.readm %v0[@w1] : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
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
      %v23 = struct.readm %v0[@out0] : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
      constrain.eq %v23, %v4 : !felt.type<"babybear">, !felt.type<"babybear">
      %v24 = struct.readm %v0[@out1] : !struct.type<@Addition8FullCarry>, !felt.type<"babybear">
      constrain.eq %v24, %v5 : !felt.type<"babybear">, !felt.type<"babybear">
      function.return
    }
  }
}
-/
#guard_msgs in
#eval IO.print (emit withBytes "Addition8FullCarry" (Gadgets.Addition8FullCarry.circuit (p := pBabybear)))

/-! ## Rejected (gate G8)

Every construct outside the Stage-1 subset must be refused *before* any LLZK text
exists, and the refusal must say what was hit. -/

-- A configured field whose prime is not the circuit's is a compile error, not
-- arithmetic silently performed in the wrong field.
/--
info: compilation failed:
field: configured field 'mersenne31' has prime 2147483647, but the circuit's field has 2013265921 elements
-/
#guard_msgs in
#eval IO.print (emit mersenne "Multiply" multiply)

-- An unregistered table is refused, and the diagnostic says how to register it.
/--
info: compilation failed:
operation 1 (lookup): lookup into table 'Bytes', which is not in the export registry; add its rows to `Config.tables` (`ExportTable.ofStatic` derives them from a `StaticTable`)
-/
#guard_msgs in
#eval IO.print (emit babybear "Addition8FullCarry" (Gadgets.Addition8FullCarry.circuit (p := pBabybear)))

-- A registry entry the renderer could not emit is refused before any lowering,
-- and every problem with it is reported at once.
/--
info: compilation failed:
table 'not a symbol': name is not a legal MLIR symbol; it must start with a letter or underscore and contain only letters, digits and underscores
table 'not a symbol': arity is 2; only single-column tables are supported, because a wider one needs an `array.new` query and a multi-dimensional `constrain.in`
table 'not a symbol': row 0 has 1 value(s) but the arity is 2
-/
#guard_msgs in
#eval IO.print (emit
  { field := .babybear, tables := #[{ name := "not a symbol", arity := 2, rows := #[#[0]] }] }
  "Multiply" multiply)

-- A witness built from a conditional is refused by name, not by a generic
-- "unsupported" message.
/--
info: compilation failed:
operation 0 (witness): unsupported witness expression: `ite` (a conditional); it needs `scf.if`, which is a later increment
-/
#guard_msgs in
#eval IO.print (emit babybear "IsZeroField" (Gadgets.IsZeroField.circuit (F := F pBabybear)))

end LLZK.Test.Circuit
