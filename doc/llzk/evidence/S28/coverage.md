# S28 measured coverage delta

Date: 2026-08-22

Authority: `Clean/Backend/LLZK/Test/Coverage.lean`. Every row below is a
compile-time guard; this file records the reviewed interpretation.

| gadget | S26 | S28 |
|---|---|---|
| `Xor32` | 1 `lxor` + 4 table refusals | 1 `lxor`, 0 table refusals |
| `And.And8` | 1 table refusal | compiles |
| `BLAKE3.G` | 4 `lxor` + 16 table refusals | 4 `lxor`, 0 table refusals |
| `Keccak256.Theta` | 50 `lxor` + 400 table refusals | 50 `lxor`, 0 table refusals |
| `IsZeroField` | 1 `ite` refusal | unchanged: 1 `ite` refusal |

The seven pre-existing arithmetic rows continue to compile. S28 removes every
measured multi-column registry refusal and does not remove any D033 witness
refusal. This is the intended boundary: `And8` is unlocked because its bounded
`land` witness already became admissible in S26; XOR-family gadgets remain
refused because their byte bounds are not visible in witness IR.

The external-tool corpus grows from 14 artifacts / 45 vectors / 8 source-backed
entries to 15 / 51 / 9. The new `And8` vectors are:

```text
[0,0], [1,2], [128,255], [255,255], [256,1],
[2013265920,2013265920]
```

The last two lie outside the gadget assumptions and therefore test compute
agreement only; the first four cover byte boundaries. Both LLZK witness
backends are required to match Clean on all six by the final G0-G12 run.
