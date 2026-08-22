# S29 Phase XC — Xor32 reference and semantic evidence

## Frozen implementation

- Implementation commit X:
  `06b80f2f48b3c6c7c850062e596dde92ab11d82e`.
- Sole parent: Xor32 proof-evidence tip
  `e2b73edeb08891969313683600b0e6c63d48cae1`.
- Accepted LLZK source:
  `25fb3740ea3465c9129a06289297bb4f0554b7a5`.
- Accepted immutable LLZK output:
  `/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0`.

X adds Xor32 to the external corpus under the certified Bytes and ByteXor
registries. It carries seven normalized theorem-domain rows and three
compute-only wide-input rows. Every row has a fixed public reference which is
checked against Clean before the expected full-witness and public JSON are
emitted.

## Independent reference construction

`xor32_oracle.py` is a standalone standard-library Python script which imports
neither Clean nor LLZK. For normalized rows it packs
each four-byte operand as a little-endian 32-bit word, XORs the two words, and
splits the result back into four little-endian bytes:

```text
xWord = sum(x[i] << (8*i))
yWord = sum(y[i] << (8*i))
out[i] = ((xWord XOR yWord) >> (8*i)) & 255
```

For compute-only rows it independently evaluates the executable witness rule
`(x[i] & 0xff) XOR (y[i] & 0xff)`. It also computes the retired behavior
`(x[i] XOR y[i]) % 2013265921`; every one of the twelve wide lanes must differ.

| name | scope | x limbs | y limbs | fixed output | old raw output |
|---|---|---|---|---|---|
| `spec_zero` | spec | 0,0,0,0 | 0,0,0,0 | 0,0,0,0 | — |
| `spec_all_ones` | spec | 255,255,255,255 | 0,0,0,0 | 255,255,255,255 | — |
| `spec_high_bit` | spec | 128,128,128,128 | 0,1,127,255 | 128,129,255,127 | — |
| `spec_alternating` | spec | 170,85,170,85 | 85,170,85,170 | 255,255,255,255 | — |
| `spec_equal` | spec | 0,1,128,255 | 0,1,128,255 | 0,0,0,0 | — |
| `spec_lane_markers` | spec | 1,2,4,8 | 16,32,64,128 | 17,34,68,136 | — |
| `spec_mixed_word` | spec | 18,52,86,120 | 135,101,67,33 | 149,81,21,89 | — |
| `compute_x_wide` | compute only | 256,257,511,65535 | 1,2,128,170 | 1,3,127,85 | 257,259,383,65365 |
| `compute_y_wide` | compute only | 0,255,85,170 | 256,257,511,65535 | 0,254,170,85 | 256,510,426,65365 |
| `compute_both_wide` | compute only | 2013265920,65536,1000,65706 | 257,511,65535,2013265920 | 1,255,23,170 | 256,66047,64535,65705 |

`Clean/Backend/LLZK/Corpus.lean` carries these rows as `xor32Vectors` and
`xor32Entry`; `Clean/Backend/LLZK/Test/Corpus.lean` independently duplicates
and pins the expected carrier. Those tests pin the exact row names and order, every input, scope, output,
width, canonicality property, directional wide-input shape, and all twelve raw
inequalities. A mutation of every output position is red, as are fixed-reference
downgrade, input association, scope-classification, width, and canonicality
mutations.

## Oracle reproduction

Commands on exact X:

```text
python3 --version
python3 doc/llzk/evidence/S29/xor32_oracle.py
python3 -O doc/llzk/evidence/S29/xor32_oracle.py
```

Results:

```text
Python 3.12.3
oracle source SHA-256:
  e1efb2f5fe852b60b1be7265c79b99b772db787cb444937a964b273204f8720c
normal stdout: 60 lines, SHA-256
  75e2a3ebbbe92a60850b6c6a84458a1bf76fa1ab8125e257197991b29921e0d3
python -O stdout: 60 lines, the same SHA-256
  75e2a3ebbbe92a60850b6c6a84458a1bf76fa1ab8125e257197991b29921e0d3
```

The script uses explicit failing `require` checks rather than Python assertions,
so optimized mode retains its cardinality, canonicality, and discriminator
checks. Its stdout prints every source limb, fixed result, normalized word
calculation or raw result, and the conversion rule; the hash above binds that
complete output.

## Proof and runtime boundary

`LLZK.Test.Soundness.xor32_spec_of_compile` consumes the emitted module's
lookup-row satisfaction and proves the gadget `Spec` under the explicit
normalized-byte assumptions. Those assumptions hold for the seven spec rows.
They do not hold for the three wide rows, which are deliberately compute-only:
the pinned `llzk-witgen` says it ignores `constrain()` and therefore does not
establish the gadget assumptions, lookup satisfaction, or `Spec`.

All ten rows nevertheless execute in both witgen backends and both output
scopes. Fixed independent references cover the public values. Internal `w0`
through `w3` cells retain Clean/G9 differential provenance rather than an
independent public-reference claim. Extra exhaustive attacks mutate every
`out0` through `out3` on compute rows 7, 8, and 9. Row 9 additionally presents
the exact old raw full witness and public result to both backends/scopes and
requires rejection. Rows 7 and 8 do not receive a separate external raw-pair
attack.

D017 remains unchanged: the repository has no formal LLZK semantics, and the
toolchain has no constraint executor. Phase XC is external compute evidence and
a theorem relative to named assumptions, not a verified translator or an
empirical proof of `@constrain` semantics.

This evidence/status closure is a later documentary commit. It records the
complete clean run on exact XC implementation commit `06b80f2f48b3c6c7c850062e596dde92ab11d82e`;
it does not claim that the later documentary commit itself received G0–G12. No
branch was pushed and no external state changed.
