# R6-2 — what the toolchain does and does not catch in `@constrain`'s text

GAPS.md item 2 says nothing establishes that `Module.render` is faithful for
`@constrain`. Until R6 its witness was a mutation the toolchain *does* catch.
This file is the reproduction of both directions.

Tools: `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0`, LLZK 3.0.0.
Subject: `Addition8FullCarry.llzk`, from

```bash
lake env lean --run Clean/Backend/LLZK/EmitMain.lean "$OUT"
```

## Caught: swapping `constrain.in`'s operands

The two operands have different types, so the type suffix disagrees with the
operands whichever way the renderer moves them.

```bash
sed 's/constrain.in %v6, %v4 :/constrain.in %v4, %v6 :/' Addition8FullCarry.llzk > swap-in.llzk
llzk-opt swap-in.llzk
# error: use of value '%v4' expects different type than prior uses:
#        '!array.type<256 x !felt.type<"babybear">>' vs '!felt.type<"babybear">'
# exit 1
```

Moving the types with the operands does not help:

```bash
llzk-opt swap-both.llzk
# error: custom op 'constrain.in' invalid kind of Type specified
# exit 1
```

So G3 is a real check on this statement form, and the entry's original
counterexample was wrong.

## Not caught: the three forms that only `@constrain` contains

`readMember`, `constrainEq` and `constrainIn` are emitted into `@constrain` and
nowhere else. `@compute` uses `writeMember`, `feltConst`, `feltBin` and
`structNew`. So a `Stmt.render` bug confined to the first three cannot appear in
the function G5–G7 execute.

### Every member read renamed to `@w0`

```bash
sed 's/struct.readm %v0\[@w[0-9]*\]/struct.readm %v0[@w0]/' Addition8FullCarry.llzk > readm-w0.llzk
llzk-opt readm-w0.llzk                                          # exit 0
llzk-opt --verify-roundtrip readm-w0.llzk                       # exit 0
llzk-opt --llzk-full-inlining --llzk-product-program readm-w0.llzk   # exit 0
llzk-witgen readm-w0.llzk --inputs …0.inputs.json \
  --output-scope=full-witness --check-output …0.expected.json   # exit 0 (both backends)
```

`@w0` exists and has the right type, so the module is well-formed LLZK; it is a
different constraint system.

### Every `constrain.eq` dropped

```bash
grep -v '^      constrain.eq' Addition8FullCarry.llzk > no-eq.llzk   # 4 lines -> 0
llzk-opt no-eq.llzk                                             # exit 0
llzk-opt --verify-roundtrip no-eq.llzk                          # exit 0
llzk-opt --llzk-full-inlining --llzk-product-program no-eq.llzk # exit 0
llzk-witgen no-eq.llzk … --check-output …                       # exit 0 (both backends)
```

This is R2's Control 4 — `Addition8FullCarry` with an empty `@constrain` —
reached through the renderer rather than through the lowering. G9 is what closed
Control 4, and G9 compares `Module`s, so it does not close this one.

## What this changes

Nothing about what is emitted; the emitter is unchanged and every gate is green.
It replaces a false statement about the boundary with a true one, and it says
which three `Stmt` constructors a renderer proof would have to cover first.
