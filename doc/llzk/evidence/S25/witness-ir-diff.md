# S25 witness-IR alignment

Compared revisions:

- previous accepted Clean base: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`;
- fetched and accepted upstream base:
  `0e53b9f2d05f06defa2aa0a859f549b611583f10`;
- compatibility implementation: `6ccca6f862f3fdb13c8d418849aacb98e9841287`.

The fetched base is the 2026-08-04 merge of upstream PR 443, uses Lean 4.32.2,
and is 70 commits after the previous accepted base.

## Constructor inventory and disposition

| Sort | Upstream change | S25 disposition |
|---|---|---|
| `FExpr` | removed `envGet`; renamed `ofNat` to `ofU64` | accepted expressions stay structural; the two old whole div/mod shapes are translated to their `ofU64` forms; every other constructor has an explicit diagnostic |
| `NExpr` / `U64Expr` | deleted unbounded `NExpr`; added wrapping `U64Expr` with `const`, `val`, `idx`, `localVar`, `add`, `mul`, `div`, `mod`, `land`, `lor`, `lxor`, `shiftL`, `shiftR`, and `ite` | exhaustive diagnostics name every constructor; only `div/mod (val x) (const c)` under `ofU64` are accepted |
| `BExpr` | added `flt` and `bit`; retained `true`, `false`, `feq`, `neq`, `lt`, `not`, and `and` | conditionals remain rejected; an exhaustive root-condition description makes `flt` and `bit` explicit and both have red fixtures |
| `VExpr` | added `envRange` and `bitsOf` beside `lit`, `append`, and `mapRange` | only literal output vectors remain accepted; both new constructors have explicit red fixtures |
| `Step` | renamed/retyped `letN` to `letU`; locals changed from `F ⊕ Nat` to `F ⊕ UInt64` | all steps remain rejected; `letF` and `letU` are distinguished, and `letU` has its own red fixture |

The accepted source language did not grow. This was deliberate: S25 is a
compatibility change, while structural u64/bitwise support belongs to S26.

## The non-rename: `U64Expr.val`

The old `NExpr.val` returned the exact `FiniteField.val`. The new
`U64Expr.val` evaluates through `UInt64.ofNat`, truncating modulo `2^64`.
Therefore the emitted felt div/mod reading agrees with the Clean source bridge
only when every field representative is below `2^64`. S25 makes that condition
an explicit premise of `LLZK.WExpr.eval_ofWitgen` and records it as D026.

The two field questions are deliberately shown separately:

| LLZK field | Prime | `size ≤ 2^64`, so `val` does not truncate | Felt can contain every u64 directly |
|---|---:|---:|---:|
| babybear | 2013265921 | yes | no |
| koalabear | 2130706433 | yes | no |
| mersenne31 | 2147483647 | yes | no |
| goldilocks | 18446744069414584321 | yes | no |
| bn254 | 21888242871839275222246405745257275088548364400416034343698204186575808495617 | no | yes |
| grumpkin | 21888242871839275222246405745257275088696311157297823662689037894645226208583 | no | yes |

Thus the current meaning theorem covers the four small fields but not
bn254/grumpkin `val`-rooted div/mod witnesses. Conversely, only bn254 and
grumpkin can host arbitrary u64 values as one felt. S26 must choose a proved
range/limb policy, explicit truncating semantics, or a refusal; S25 does not
silently make that design choice.

## VeIR seam remeasurement

Clean's move to Lean 4.32.2 removes the original toolchain-mismatch half of
D001. The accepted project VeIR pin was rechecked at
`eae1c27e7842c0503233ec99155c39791bd5f502`: it remains on Lean 4.31.0-rc2,
has no LLZK Struct or Array dialect modules, and `Veir/OpCode.lean` explicitly
defers `constrain.in` until Array types land and `function.call` until its call
phase. D003 therefore remains binding because of dialect coverage, not because
of an assumed toolchain mismatch.
