# S29 Phase HC — BLAKE3.G reference and semantic evidence

## Frozen implementation

- External-promotion implementation HC:
  `a3299ca06576b81586ddbe56a9de711e12f1a8cd`.
- Sole parent, proof and exact-shape boundary HP:
  `f3951231928568bf97a17176a84691fd3752ef59`.
- Reference-contract ancestor HR:
  `ec1b7e18925128dc12dae2d8cb6a8935b3c6c828`.
- Accepted LLZK source:
  `25fb3740ea3465c9129a06289297bb4f0554b7a5`.
- Accepted immutable LLZK output:
  `/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0`.
- Checked-main compatibility source:
  `b5c110d1088e93d6786f66ec1e155be87bae755f`.
- Checked-main immutable LLZK output:
  `/nix/store/hvvbkw0afshj37zpiilw0jwxjxfad4p4-llzk-release-3.0.0`.

HC promotes exactly `Gadgets.BLAKE3.G.circuit 0 1 2 3` under the certified
Bytes and ByteXor registries. It carries six normalized theorem-domain rows.
Each row has 64 fixed official-reference-derived public outputs, checked equal
to Clean before expected JSON is emitted. Its 96 internal witness cells remain
Clean/G9-derived; they are not presented as independently referenced values.

## Independent reference construction

`blake3g_oracle.py` is a standalone standard-library Python transcription. It
imports neither Clean nor LLZK. Its authority is the official BLAKE3 repository
at commit `f3149ec5bb5449af877ba20377a11008ff499fa2`, specifically the eight-step
`g` definition at `reference_impl/reference_impl.rs:41-50`. The repository chose
the six rows below; they are official-reference-derived cases, not upstream
BLAKE3 test vectors, and the upstream Rust implementation was not executed.

The oracle implements wrapping 32-bit addition and rotate-right by 16, 12, 8,
and 7 in the official operation order. Words become Clean limbs by

```text
limb_i = (word >> (8*i)) & 255, i = 0..3
```

and the oracle checks that explicit shifts/masks agree with Python little-endian
`int.from_bytes`/`to_bytes` and round-trip every word. These are two formulations
inside one independent Python oracle, not two independent implementations.

| row | scope | input pattern | x / y | updated state words 0–3 | binary-add carries |
|---|---|---|---|---|---|
| `spec_zero` | spec | all state words zero | `00000000` / `00000000` | `00000000 00000000 00000000 00000000` | `000000` |
| `spec_max_bytes` | spec | all state words `ffffffff` | `ffffffff` / `ffffffff` | `000fffdc 3db81be4 dc020dfe dc000dff` | `111110` |
| `spec_alternating` | spec | alternating `aaaaaaaa` / `55555555` | `aaaaaaaa` / `55555555` | `ffcfff2d 0d06d045 7ca7dda9 d2003300` | `011101` |
| `spec_carry_heavy` | spec | `80808080 00000001 fffffffe ffffffff`, then zero | `fffffffe` / `7fffffff` | `f8487885 071b9f7f 7a084784 fa87c807` | `011101` |
| `spec_high_bit` | spec | `80000000 00000000 80000000 ffffffff`, then zero | `80000000` / `00000001` | `fff80000 0301eff0 7f0007fe ff0007ff` | `011001` |
| `spec_lane_markers` | spec | distinct byte markers in all 16 state words | `13121110` / `17161514` | `15b24e69 728767ce a231c578 7d0faa5c` | `000010` |

Every row checks that state words 4–15 remain unchanged. The lane-marker row
also has 64 pairwise-distinct nonzero output bytes. Complete 18-word inputs and
16-word outputs are printed and bound by the oracle stdout hash below.

`Corpus.lean` carries the rows in the production entry. `Test/Corpus.lean`
independently duplicates and pins the names, order, all 72 input limbs, scope,
all 64 outputs, fixed-required policy, and G9 participation. Emission validates
fixed-output width and canonicality, stored-witness input association, and exact
positional equality with Clean before using the fixed public values. Production
BLAKE word guards and the external helper separately enforce input range and
canonicality.

## Oracle reproduction

Commands on exact HC:

```text
python3 --version
python3 doc/llzk/evidence/S29/blake3g_oracle.py
python3 -O doc/llzk/evidence/S29/blake3g_oracle.py
```

Results:

```text
Python 3.12.3
oracle source SHA-256:
  788b8a8a6af8cfcfd1b2e8a4e567bee374ff5b0b14c116e0ecefddc5746eea75
normal stdout: 51 lines, SHA-256
  e0cb9ec3ec465e4ae65bd03b857a5c216a99bb3dc42da0390a54fa03d0df3364
python -O stdout: 51 lines, the same SHA-256
  e0cb9ec3ec465e4ae65bd03b857a5c216a99bb3dc42da0390a54fa03d0df3364
```

The script uses explicit failing `require` checks rather than Python assertions,
so optimized mode retains its operation, width, endian, unchanged-tail,
canonicality, and marker checks. The oracle is byte-identical from HR through
HC; the committed theorem probe is byte-identical from HP through HC.

## Proof and runtime boundary

`LLZK.Test.Soundness.blake3g_spec_of_compile` is a conditional implication for
exact `G 0 1 2 3`. Given successful compile, recognition, and module readback;
an assignment satisfying every reader-extracted equality and ordered lookup
row; exact input evaluation; and the gadget's normalized assumptions, the
evaluated outputs satisfy the gadget `Spec`. The primary form consumes module
reader `LookupRowsHold`; its convenience form consumes resolved Clean source
memberships. The concrete lookup proof classifies all 72 rows as 56 Bytes plus
16 ByteXor, and no-interaction is proved for this instantiation.

The probe pins that complete premise/conclusion interface but retains the
compilation, readback, recognition, equality, lookup, input, and assumption
hypotheses. The `.isSome`/`.isOk` guards separately establish capability. It is
not a closed proof that a particular witgen execution discharges the theorem's
premises.

All six normalized rows execute in both LLZK witness backends and both output
scopes. That empirically connects the fixed public outputs to Clean and LLZK
compute behavior. It does not kernel-prove per-vector equality/lookup
satisfaction: witgen ignores `@constrain`. D017 remains unchanged; the project
does not have a formal LLZK semantics or a verified translator. The generic
caller-selected source-table identity gap also remains, although the exact
BLAKE3.G instantiation discharges `resolve` through its circuit-specific proof.

This evidence/status closure is a later documentary commit. It records the
complete clean runs on exact HC implementation commit
`a3299ca06576b81586ddbe56a9de711e12f1a8cd`; it does not claim that the later
documentary commit itself received G0–G12. No branch was pushed and no external
state changed.
