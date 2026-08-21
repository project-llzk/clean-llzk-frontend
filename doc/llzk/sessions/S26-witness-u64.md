# S26 — Lower `U64Expr` structurally, and stop matching whole shapes

Status: proposed
Depends on: **S25 must have landed with all gates green.** This packet is
unexecutable before it — it is written against constructors that do not exist at
`1e563b9c`.
Base integration commit: S25's resulting commit
Worktree: `/home/alh/LLZK/clean-llzk-frontend`
Branch: off S25's branch, or off `integration` once S25 has merged

## Objective

Replace D011's two hand-matched natural shapes with a structural lowering of
`Witgen.U64Expr`, and take `VExpr.bitsOf` and the bitwise operations with it.

Measured payoff, from `ROADMAP.md`'s coverage table: the whole bitwise half of
Clean's gadget library is refused today for exactly one reason. `Xor.Xor32`,
`And.And8`, `BLAKE3.G` and `Keccak256.Theta` all fail on `lxor`/`land`, and
`Keccak256.Theta` alone produces 450 diagnostics. This session is what turns
those into modules.

## Must read

- `doc/llzk/DECISIONS.md` — **D011 and D025**, in that order. D011 is the
  argument this session retires; D025 is why it can be retired.
- `doc/llzk/GAPS.md` — §7 is the boundary this work sits inside and cannot cross.
- `doc/llzk/evidence/S25/witness-ir-diff.md` — the u64-per-field table.
- `Clean/Backend/LLZK/Witness.lean` and `WitnessCheck.lean` as S25 left them.

## The design question to settle first, before writing any lowering

**A `u64` does not fit in most of the registry.** `U64Expr` wraps modulo `2^64`;
a felt reduces modulo `p`. These agree only when every intermediate value stays
below `p`.

| field | prime | holds a full `u64`? |
|---|---|---|
| babybear | `2013265921` ≈ 2³¹ | no |
| koalabear | `2130706433` ≈ 2³¹ | no |
| mersenne31 | `2147483647` = 2³¹−1 | no |
| goldilocks | `2^64 − 2^32 + 1` | **almost** — below `2^64`, so no, not faithfully |
| bn254 | ≈ 2²⁵⁴ | yes |
| grumpkin | ≈ 2²⁵⁴ | yes |

So there are three honest options, and **picking one is this session's first
deliverable, recorded as a decision entry before any code**:

1. **Accept `U64Expr` only over fields that hold a `u64`** — bn254 and grumpkin.
   Cheapest and immediately useful — but **not "sound" as this line used to say**
   (R7-11): on exactly those two fields `U64Expr.val` *truncates* `ZMod.val` to
   64 bits (see S25 Deliverable 2a), so faithfulness on the wide fields needs a
   bound on the field element under every `val`, which a `U64Expr → Option Nat`
   analysis cannot see — the hazard is on **both** ends of this table. Costs the
   babybear corpus, which is most of what exists today, so it cannot be the
   whole answer.
2. **Range-bound the values and accept narrower widths.** Most real uses are not
   64-bit: `AssertBytes` needs 8, `U32` gadgets need 32. If recognition can prove
   an expression's values stay below `2^k` with `2^k < p`, the lowering is
   faithful on babybear too. Needs a bound analysis on `U64Expr` — the real work
   of this option, and the one that keeps the existing corpus.
3. **Limb decomposition.** General and much larger. Do not start here.

**Recommendation: (2), with (1) as its degenerate case** — a field that holds a
`u64` has the bound for free. Write the bound analysis as a total function
`U64Expr → Option Nat` returning a proven upper bound, and refuse when it returns
`none`. That keeps the fail-closed discipline D004 sets and makes the field
question a side condition rather than a special case. **The decision entry must
also cover the `val` bridge** (R7-11): what bound on `FiniteField.val x` makes
`U64Expr.val x` exact, who establishes it, and what is refused when nothing
does — field width alone does not settle it.

Whatever is chosen: it must be stated as a *theorem or a refusal*, never as
prose. D011's own history is the warning — R2-05 found its central side condition
unstated for four sessions, and closing it needed a whole class (D019).

## Allowed scope

- `Clean/Backend/LLZK/{Witness,Expression,IR,Circuit,WitnessCheck}.lean`
- `Clean/Backend/LLZK/{Examples,Corpus}.lean` and `Test/`
- `doc/llzk/{DECISIONS,GAPS,ROADMAP,CURRENT}.md`
- `scripts/llzk/e2e.sh` — only the `LLZK_EXPECTED_*` counts

## Deliverables

1. **A decision entry** settling the width/field question above, before code.
2. **A bound analysis** on `U64Expr`, if option (2): total, fail-closed, with the
   theorem that a bounded expression's `U64Expr.eval` agrees with the lowering.
3. **Structural lowering of `U64Expr`** replacing the two whole-shape matches:
   `add`/`mul`/`div`/`mod` to `felt.add`/`mul`/`uintdiv`/`umod`, and
   `land`/`lor`/`lxor`/`shiftL`/`shiftR` to whatever LLZK offers — **check the
   dialect before designing.** `IR.FeltBinOp` today has only
   `add`/`mul`/`uintdiv`/`umod`; the scoping notes claim `felt.bit`, `felt.shl`,
   `felt.shr` exist. Confirm against the pinned `llzk-opt`, do not trust the note.
4. **`VExpr.bitsOf`** as a first-class output shape.
5. **`WExpr`** extended in step, since G9's witness half compares against it, and
   `WExpr.eval`'s new cases *are* the D017 reading of the new operations — say so
   in the docstring, as `eval`'s `umod` case already does.
6. **Corpus entries** for what this unlocks — which is **less than this line
   used to claim** (R7-05): `Xor32`, `And8`, `BLAKE3.G` and `Keccak256.Theta`
   all *also* look up 3-column tables (`ByteXorTable` and kin), which D013
   refuses regardless of any witness-IR increment — the ROADMAP's corrected
   coverage table and `Test/Coverage.lean` carry the decomposition. Their
   corpus entries belong to **S28 (multi-column tables)**. What S26 itself can
   put in the corpus is bitwise/`bitsOf` circuits with no multi-column lookup —
   pure-`lxor` compositions, `bitsOf` decompositions — plus updated
   `Test/Coverage.lean` guards showing the bitwise diagnostic counts drop to
   exactly the lookup refusals.
7. **Negative fixtures** for every new rejection path, per G8.

## Non-goals

- `ite`/`BExpr` beyond what a bitwise lowering needs. `scf.if` is its own session.
- `let`-steps (`Step.letF`/`letU`), `mapRange`, `envRange`, `listGet`,
  `dataGet`/`hintGet`.
- Subcircuits as named LLZK components — still Stage 2, still after this.
- Anything in `Clean/` outside `Clean/Backend/LLZK/`.

## Acceptance gates

All twelve, plus two specific to this session:

- **The corpus grows.** `LLZK_EXPECTED_ARTIFACTS` and `LLZK_EXPECTED_VECTORS` go
  up, and the new modules pass G3, G4, G5, G6, G7 and G10a. A capability that
  only G9 has seen is not validated — that is the distinction
  `ROADMAP.md`'s coverage table draws between "compiles" and "validated".
- **The coverage table is re-measured**, not edited by hand. Re-run the sweep
  behind `ROADMAP.md` §"Measured coverage" and paste the new verdicts.

## Evidence

`doc/llzk/evidence/S26/`: `gates.txt`, `coverage.md` (re-measured),
`llzk-bitwise-ops.md` (what the pinned `llzk-opt` actually accepts, with the
probe commands — the R6-2 lesson: check the tool, do not trust the note).

## Handoff

- Changes made:
- Decisions made:
- Deviations:
- Blockers:
- Resulting commit:
- Exact next action: expand and execute
  `doc/llzk/sessions/S28-multicolumn-tables.md`; S27 remains returned for
  re-scoping under R7-09.
