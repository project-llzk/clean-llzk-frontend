# S26 coverage remeasurement

Date: 2026-08-21

Reproducer:

```sh
lake env lean Clean/Backend/LLZK/Test/Coverage.lean
```

The command exits 0. The checked sweep in that file measures the same 12 gadget
tops as R7 and pins both diagnostic totals and their decomposition:

| gadget | S26 verdict |
|---|---|
| `Addition8FullCarry` | compiles |
| `ByteDecomposition` | compiles |
| `Addition32` | compiles |
| `Addition32Full` | compiles |
| `Rotation32` | compiles |
| `Rotation64` | compiles |
| `Not.Not64` | compiles |
| `Xor32` | refused: 1 `lxor` bound refusal + 4 unregistered-table refusals |
| `And.And8` | refused: 1 unregistered-table refusal |
| `BLAKE3.G` | refused: 4 `lxor` bound refusals + 16 unregistered-table refusals |
| `Keccak256.Theta` | refused: 50 `lxor` bound refusals + 400 unregistered-table refusals |
| `IsZeroField` | refused: 1 `ite` refusal |

The measured change is exactly `And8`: its `land` diagnostic disappeared, so
the total fell from 2 to 1. All XOR totals remain unchanged. This is deliberate,
not an implementation miss: those gadgets' byte bounds are stored in
`FormalCircuit.Assumptions` and constraints, while their witness expressions
contain bare `.val` operands. D033's independent witness reader cannot use
evidence that is absent from `Witgen.U64Expr`, and accepting it would make
`WExpr.eval_ofWitgen` false.

The session packet predicted that all bitwise diagnostic counts would drop to
lookup refusals. The remeasurement refutes that prediction under the packet's
simultaneous theorem-or-refusal requirement. Resolving it needs a source-level
range contract or a proved constraint-to-witness analysis; S26 does not invent
one.

The external-tool corpus grows independently of this selected gadget sweep:
`LowByte` validates bounded `land`/`felt.bit_and`, and `Bits8` validates direct
bit decomposition through `felt.shr` plus `felt.bit_and`.
