# S29 — Source-visible XOR byte range and headline promotion

Status: Phase B complete on `7a0f209c`; Phase X Xor32 promotion next
Depends on: audited frontend baseline `9b46264c59ed69af24817cb4b2cfdb7ebcfb4629`
Base integration commit: `9b46264c59ed69af24817cb4b2cfdb7ebcfb4629`
Frontend branch: `clean-to-llzk/s29-xor-range-contract`
Clean overlay branch: `clean-to-llzk/s29-clean-xor-range`

## Objective

Make Xor32's byte range visible by executing it in witness semantics, prove the
generic modulo and XOR/OR bounds used to lower it, then promote Xor32 and
`BLAKE3.G 0 1 2 3` through the complete external matrix. Preserve D033's
recursive fail-closed boundary and produce one immutable candidate for R8.

The implementation order is binding:

```text
decision D
  -> reviewed Clean-only overlay K
  -> atomic overlay adoption M
  -> backend bound proof B
  -> Xor32 promotion X
  -> BLAKE3.G promotion H
  -> immutable candidate C
  -> R8
```

Every phase receives independent adversarial review before the next begins.
These reviews are pre-R8 controls, not substitutes for R8.

## Recovery already completed

At bootstrap, `CURRENT.md` named a file path as the integration commit and the
local integration branch was 102 commits behind the audited frontend. Under
`ORCHESTRATION.md` section 4.1 this became a recovery session. Local
`clean-to-llzk/integration` was fast-forwarded to `9b46264c`; no push or remote
change occurred. S29 starts from that exact reviewed integration tip. The full
two-toolchain matrix belongs to substantive audit tree `7c567f54`; `9b46264c`
is its documentation/provenance closure.

## Required reading

- `AGENTS.md`, `CURRENT.md`, `PINS.md`, `GATES.md`, and `ORCHESTRATION.md`.
- D033, D034, and D035 in `DECISIONS.md`.
- `GAPS.md` items 1, 2, 5, 7, and 8.
- `review/FRONTEND-AUDIT-2026-08-22.md`.
- `Witness.lean`, `WitnessCheck.lean`, their tests, `Xor32.lean`,
  `BLAKE3G.lean`, `Corpus.lean`, `Examples.lean`, and the concrete lookup and
  soundness tests.

## Phase D — decision and controls before code

D035 is the semantic contract. It selects executable `% 256` narrowing,
`min numeratorBound divisor` for modulo, and
`2 ^ Nat.clog 2 (max ba bb)` for XOR/OR. It explicitly retains recursive child
admission and the wide-field `.val` refusal.

Acceptance for D:

- three independent reviewers inspect semantic soundness, branch/pin process,
  and red-control/promotion coverage;
- every confirmed finding is incorporated into this packet or D035;
- no Clean source or frontend lowering code changes before the reviewed
  decision commit.

## Phase K — isolated Clean source change

Create a separate worktree and branch from exact upstream Clean commit
`0e53b9f2d05f06defa2aa0a859f549b611583f10`, never from `origin/main` or another
moving ref. The only intended source change is
`Clean/Gadgets/Xor/Xor32.lean`:

```text
(x.val % 256) ^^^ (y.val % 256)
```

for each of four limbs, with the completeness proof updated to show narrowing
is the identity under `U32.Normalized`. Build the affected gadget, BLAKE3
composition, `Clean`, and `CleanTests`. Freeze the Clean-only commit K, record
its exact diff from upstream, and obtain independent semantic and process
review. Do not push or open an upstream issue/PR.

## Phase M — atomically adopt the Clean overlay

On the frontend branch, merge final K with `--no-ff --no-commit`. In that same
merge commit:

- set the accepted Clean overlay pin to K;
- retain upstream base U=`0e53b9f2` as a distinct provenance input;
- make `check-pins.sh` verify U is an ancestor of K, K is an ancestor of HEAD,
  and the U..K Clean-core diff is exactly the reviewed overlay path;
- keep ordinary core byte identity measured from K;
- update `PINS.md`, `CURRENT.md`, and G11 tests.

Never allowlist Xor32 as a frontend-side exception. Run G0-G12 on clean M and
record exact evidence before backend support begins.

## Phase B — generic bound analysis and proofs

Change `Witness.lean` and the independent reader/proofs in
`WitnessCheck.lean` together:

- split modulo from division in `U64Expr.upperBound`;
- recursively analyze the numerator and return `min ba d` for nonzero literal
  modulo;
- derive the common XOR/OR ceiling with `Nat.clog`, guard it by the u64 modulus,
  and retain the root field-prime guard;
- update `eval_lt_upperBound` and `eval_ofWitgen` without importing circuit
  assumptions or constraints;
- preserve recursive lowering/admission of every child.

Mandatory controls:

- both the existing asymmetric `.val ^^^ 1` and a symmetric
  `.val ^^^ .val` remain red;
- one modulo-wrapped addition whose bound exceeds the Babybear prime but not
  `2^64` remains red because narrowing cannot hide felt reduction;
- a distinct modulo-wrapped addition whose bound exceeds `2^64` remains red
  because narrowing cannot hide u64 wrap;
- `.idx % 256`, local-variable modulo, dynamic modulo, modulo by zero, and
  modulo by a divisor at least the prime remain red;
- wide-field `.val % 3` and `.val % 256` remain red;
- exact modulo and XOR/OR bound guards cover 1, 2, 255, 256, 257, `2^63`, and
  `2^64`, including a ceiling which exceeds the prime;
- both `lor` and `lxor` are covered;
- G9 rejects XOR/OR substitution, a wrong XOR operand, and a wrong narrowing
  divisor.

Every G9 mutation must have a positive self-baseline first: each original and
mutated source or recognized expression independently compiles and reads green
against itself, then the cross-comparison is red. A helper returning false
because one side was unreadable is not a discriminator.

Run targeted Lean builds and the theorem/axiom probe, then full G0-G12 on a
clean B commit. Independent reviewers re-audit the source/emitter/reader
triangle and every new red branch.

Phase B is complete on exact clean implementation commit
`7a0f209ca7806a0e97173ffe84b47b9aa1f20be5`. Its complete accepted-tool matrix
passed with the unchanged 15-module/51-vector external corpus and 61 G11 paths.
The capability sweep now compiles Xor32 and BLAKE3.G directly; neither is a
promoted corpus claim yet. Proof, gate, and independent-review evidence is in
`evidence/S29/bounds.md` and `evidence/S29/bounds-gates.txt`.

## Cross-cutting harness controls

The current witness discriminator perturbs only the first JSON key. Before a
64-field public result becomes headline evidence, perturb first, middle, and
last fields in both public and full-witness expectations, and run the self-test
on the widest promoted artifact. A checker which validates only `out0` must be
red. Pin exact SMT-lowered and declared-skip counts; a minimum of one skip is no
longer sufficient. The final banner and active docs must say both backends and
both output scopes.

Add a fail-closed independent-reference layer to corpus emission. A promoted
entry carries fixed expected public outputs in addition to the witness derived
from the same Clean source; emission refuses if Clean's public result disagrees.
This prevents a shared gadget/witness defect from making the Clean-to-LLZK
differential green. Mutate the fixed reference and require the check to go red.
Fixed constants are not sufficient provenance: Xor32 results must be derived
manually or by an implementation independent of Clean, and BLAKE3.G results
must come from separately implemented or official reference code. Record the
reference implementation/version, exact command, source inputs, word outputs,
and word-to-little-endian-limb conversion in the phase evidence. Do not generate
the oracle from a Clean definition, `LLZK.witness`, or an emitted module.

## Phase X — promote Xor32

Add Xor32 under `withBytesAndXor` to the external corpus. Use separately named
normalized/spec vectors and compute-only narrowing vectors, with each group
count pinned. The vectors include zero, all ones, high-bit, alternating limbs,
equal inputs, distinct per-limb patterns, and per-limb out-of-assumption values
on both operands. The latter must distinguish the new executable narrowing from
raw XOR and are compute-only evidence because LLZK witgen ignores constraints.

Add independently derived fixed public references, exact constraint/cell/output shape guards,
concrete ByteXor lookup resolution, and `spec_of_compile` for Xor32. Update
coverage guards, showcase generation, exact counts, and both full/public
expectations. Acceptance is G0-G12 on clean X plus theorem probe, reference red
mutation, and independent review.

## Phase H — promote BLAKE3.G

Promote exactly `Gadgets.BLAKE3.G.circuit 0 1 2 3` under the heterogeneous
Bytes plus ByteXor registry. Add fixed independent reference vectors covering
zero, maximal bytes, alternating state, carry-heavy additions, high-bit data,
and distinct lane markers. Every semantic vector has byte-normalized limbs; the
marker vector also pins that lanes 4 through 15 remain unchanged.

Generate those fixed results with a separately implemented or official BLAKE3
G reference, never `Specs.BLAKE3.g` or another Clean definition. Preserve its
identity/version, invocation, source words, output words, and explicit
little-endian limb conversion in `blake3g.md`.

Pin exact constraint/cell/output shapes. Add concrete lookup resolution and
`spec_of_compile`; the proof must classify every flattened lookup between
ByteTable and ByteXorTable and may not assume a single table. Both witness
backends and both output scopes run on every vector. Update the generated
showcase with explicit Xor32 and BLAKE3.G sections naming their concrete
theorems and distinguishing spec vectors from compute-only vectors.

If any non-XOR diagnostic appears, stop and re-scope rather than broadening
S29. Acceptance is clean G0-G12, theorem/axiom probe, fixed reference-vector
red discrimination, exact updated counts/showcase/SMT split, and independent
review.

## Phase C and R8

Choose one clean immutable candidate after H. No feature changes occur during
R8. Reviewers work from a detached clean worktree and do not edit the candidate.
Re-run both LLZK toolchains, theorem probes, renderer mutations, public-output
discriminators, lookup-row attacks, source-table identity premises, and the new
range controls. Any confirmed repair creates a new candidate, reruns affected
gates, and restarts affected review lanes. Publication remains a separate,
explicitly authorized decision.

## Evidence

Preserve under `doc/llzk/evidence/S29/`:

- `bootstrap.md` — base, recovery, branches, pins, and reviewer findings;
- `clean-overlay.md` — U..K diff, build commands, results, and review;
- `adoption-gates.txt` — clean M matrix;
- `bounds.md`, `probe.lean`, and `bounds-gates.txt` — B proofs and gates;
- `xor32.md` and `xor32-gates.txt` — vectors, theorem, and X gates;
- `blake3g.md` and `blake3g-gates.txt` — references, theorem, and H gates;
- phase-specific independent review findings and dispositions.

Evidence records the commit actually tested. A later evidence commit may point
to M/B/X/H; it may not retroactively attribute a dirty-tree run.

## Non-goals

- Keccak promotion, Xor64, Or8, generic wide-field `.val` narrowing, constraint
  inference, trusted range annotations, loops, `ite`, inversion, dynamic tables,
  AIR, or a verified translator.
- Pushing branches, opening issues/PRs, advancing the remote integration branch,
  changing organization settings, or publication.
