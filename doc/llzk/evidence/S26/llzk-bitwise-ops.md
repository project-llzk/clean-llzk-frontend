# S26 pinned-LLZK bitwise probe

Date: 2026-08-21

Tool under test:

```text
LLZK_BIN=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin
accepted source pin=25fb3740ea3465c9129a06289297bb4f0554b7a5
```

`$LLZK_BIN/llzk-opt --print-llzk-ops` reports these relevant exact
operation names:

```text
felt.bit_and
felt.bit_or
felt.bit_xor
felt.shl
felt.shr
```

There is no `felt.bit`; the scoping note that used that spelling was not used as
an API contract.

## Static-operand probe

Input artifact: `bitwise-probe.llzk`; inputs: `bitwise-probe.inputs.json`.
The artifact applies all five operations to constants and additionally shifts
by 64.

Commands (all exited 0):

```sh
$LLZK_BIN/llzk-opt doc/llzk/evidence/S26/bitwise-probe.llzk -o /tmp/s26-bitwise-parse.mlir
$LLZK_BIN/llzk-opt --verify-roundtrip doc/llzk/evidence/S26/bitwise-probe.llzk -o /tmp/s26-bitwise-roundtrip.mlir
$LLZK_BIN/llzk-opt --llzk-full-inlining --llzk-product-program doc/llzk/evidence/S26/bitwise-probe.llzk -o /tmp/s26-bitwise-product.mlir
$LLZK_BIN/llzk-witgen doc/llzk/evidence/S26/bitwise-probe.llzk --inputs doc/llzk/evidence/S26/bitwise-probe.inputs.json --output-scope=full-witness
$LLZK_BIN/llzk-witgen doc/llzk/evidence/S26/bitwise-probe.llzk --inputs doc/llzk/evidence/S26/bitwise-probe.inputs.json --backend=execution-engine --output-scope=full-witness
```

Both witness backends returned the same signals:

```json
{
  "and": "192",
  "or": "252",
  "xor": "60",
  "shl4": "3840",
  "shr4": "15",
  "shl64": "1476396101",
  "shr64": "0"
}
```

The count-64 result is a semantic boundary, not an accepted source case. Lean's
`UInt64` shifts mask the count modulo 64, so shifting 240 by 64 returns 240;
LLZK does not mask it (`shr64 = 0`, and `shl64` is the field-reduced result).
D033 therefore requires a literal count below 64.

## Dynamic-operand probe

Input artifact: `bitwise-dynamic-probe.llzk`; inputs set `a = 240`, `b = 4`.

Commands (all exited 0):

```sh
$LLZK_BIN/llzk-opt doc/llzk/evidence/S26/bitwise-dynamic-probe.llzk -o /tmp/s26-bitwise-dynamic-parse.mlir
$LLZK_BIN/llzk-opt --verify-roundtrip doc/llzk/evidence/S26/bitwise-dynamic-probe.llzk -o /tmp/s26-bitwise-dynamic-roundtrip.mlir
$LLZK_BIN/llzk-opt --llzk-full-inlining --llzk-product-program doc/llzk/evidence/S26/bitwise-dynamic-probe.llzk -o /tmp/s26-bitwise-dynamic-product.mlir
$LLZK_BIN/llzk-witgen doc/llzk/evidence/S26/bitwise-dynamic-probe.llzk --inputs doc/llzk/evidence/S26/bitwise-dynamic-probe.inputs.json --output-scope=full-witness
$LLZK_BIN/llzk-witgen doc/llzk/evidence/S26/bitwise-dynamic-probe.llzk --inputs doc/llzk/evidence/S26/bitwise-dynamic-probe.inputs.json --backend=execution-engine --output-scope=full-witness
```

Both backends returned:

```json
{
  "and": "0",
  "or": "244",
  "xor": "244",
  "shl": "3840",
  "shr": "15"
}
```

Thus parse/verify, round-trip, product-program conversion, interpreter witness
generation, and execution-engine witness generation all cover the exact dialect
spellings used by S26.
