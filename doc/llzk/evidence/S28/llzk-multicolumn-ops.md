# S28 pinned-LLZK multi-column lookup probe

Date: 2026-08-21

Inputs under test:

```text
accepted LLZK source pin=25fb3740ea3465c9129a06289297bb4f0554b7a5
LLZK_BIN=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin
llzk-opt reported LLZK version 3.0.0, LLVM 20.1.8
llzk-witgen reported LLZK version 3.0.0, LLVM 20.1.8
```

The source revision was fetched by exact object ID and inspected through
`FETCH_HEAD`; the local `llzk-lib` checkout was not treated as the pin.

## Primary-source contract

At the accepted source object:

- `include/llzk/Dialect/Array/IR/Ops.td` specifies that a static `array.new`
  receives exactly the product of its dimensions in row-major order. Its
  examples include four scalar operands producing `!array.type<2,2 x
  !felt.type>`.
- `include/llzk/Dialect/Constrain/IR/Ops.td` permits the right operand of
  `constrain.in` to be a suffix-dimensional subarray of its left operand. For
  an `N`-dimensional left operand and an `M`-dimensional right operand, `N >= M`;
  a scalar is the `M = 0` case.
- `test/Dialect/Constrain/emit_pass.llzk` contains the accepted form
  `constrain.in %b, %a : !array.type<89,2 x index>, !array.type<2 x index>`.
- `test/Dialect/Constrain/emit_fail.llzk` pins rejection when the suffix
  dimensions disagree or the right operand has more dimensions than the left.
- `test/Dialect/Global/globals_pass.llzk` establishes that a multidimensional
  constant uses one flat row-major builtin array initializer, for example
  `!array.type<2,2 x i1> = [0,1,1,0]`. `globals_fail.llzk` checks the initializer
  count against the product of every dimension.

This is a true multidimensional `array.type`, not recursive nesting. A direct
probe of `!array.type<2 x !array.type<3 x felt>>` was rejected with:

```text
'array.type' element type cannot be 'array.type'
```

The backend IR must therefore retain an ordered dimension vector. Reusing its
old recursive `(size, elem)` constructor would spell a type that the accepted
dialect rejects.

## Direct positive probe

The preserved input is `multicolumn-probe.llzk`. It declares a `2 x 3` constant
with flat row-major values, constructs `[1,2,3]` with `array.new`, reads the
global, and constrains the whole three-field row to be a member.

These commands all exited 0:

```sh
$LLZK_BIN/llzk-opt doc/llzk/evidence/S28/multicolumn-probe.llzk --verify-roundtrip
$LLZK_BIN/llzk-opt doc/llzk/evidence/S28/multicolumn-probe.llzk --llzk-full-inlining --llzk-product-program
$LLZK_BIN/llzk-witgen doc/llzk/evidence/S28/multicolumn-probe.llzk --inputs=doc/llzk/evidence/S28/multicolumn-probe.inputs.json --output-scope=public
```

Round-trip retained the `2,3` global type, the `3`-element row type, and the
row-valued `constrain.in`. Product formation lowered `array.new` to a
three-element allocation followed by writes and retained the same membership
constraint. Witgen returned `{}` as expected for the memberless component.

`llzk-witgen` version 1 explicitly ignores `@constrain`. Its success proves that
the module can execute its compute semantics; it is not evidence that the
lookup holds, nor a replacement for the certificate theorem. This remains the
D017 boundary.

## Direct negative probes

Two mutations were also sent directly to the accepted `llzk-opt`:

1. Replacing the true `2,3` type by a recursively nested array type was rejected
   because an `array.type` cannot itself be the element type of `array.type`.
2. Keeping the table at `2,3` but constructing a two-element query row was
   rejected with `cannot unify array dimensions [3] with [2]`.

These results settle the lowering surface: table values remain nested rows in
the backend data model, render as one flat row-major initializer with a genuine
`[row-count, arity]` LLZK dimension vector, and are queried by one ordered
one-dimensional row. Single-column lookup data remains row-shaped internally;
the existing scalar LLZK spelling may remain as the degenerate arity-one case.
