# S05 — The two recognized natural division/modulo shapes

Status: accepted  
Depends on: S04  
Base integration commit: `ce514056`  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Accept the two natural division/modulo witness shapes Addition8 needs, and keep
every other natural expression rejected.

## Must read

- `doc/llzk/ARCHITECTURE.md` §4.5.
- `doc/llzk/DECISIONS.md` D009, D011.

## Deliverables

- `FieldExpr.uintdiv` / `FieldExpr.umod`, with a literal divisor.
- Whole-shape recognition in `Witness.ofFExpr`, with divisor side conditions.
- One positive fixture (`decompose`) and two negative ones.

## Non-goals

- General natural arithmetic. The principled route — `cast.toindex`, `arith` on
  `index`, `cast.tofelt` — needs a bounds policy and interpreter support that do
  not exist yet, and is a separate decision, not an implicit backlog item.
- Lookups (S06).

## Acceptance gates

- G1: PASS. G2: PASS. G8: PASS.
- G3–G7: not claimed.

## Evidence

`doc/llzk/evidence/S05/gates.txt`

## Handoff

- Changes made: two `FieldExpr` constructors and their lowering; whole-shape
  recognition plus `checkDivisor` in `Witness.lean`; the configured prime is now
  threaded into the witness recognizers; three fixtures.
- Decisions made: D011.
- Deviations: S05 ran before S01/S02, as S03 and S04 did. The soundness argument
  for these two shapes (D011) is the most load-bearing prose in the backend so
  far and is exactly what gates G5/G6 would test empirically — so the missing
  tooling matters more for this increment than for the previous ones.
- Blockers: S01 still needs `sudo systemctl restart nix-daemon`.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: S06 — the table export registry, so `Addition8FullCarry`
  compiles. Its last remaining diagnostic is the `Bytes` lookup.
