# S01 — Provision current LLZK 3.0 tools

Status: proposed  
Depends on: S00  
Base integration commit: pending S00 acceptance  
Worktree: dedicated session worktree  
Branch: `clean-to-llzk/s01-tooling`

## Objective

Make pinned LLZK 3.0 `llzk-opt` and `llzk-witgen` reproducibly available.

## Deliverables

- Reproducible acquisition or build path.
- Exact binary locations and version evidence.
- Doctor checks that reject the installed LLZK 2.0 package.
- Updated `PINS.md`, `GATES.md`, and S01 evidence.

## Non-goals

- Frontend implementation.
- Golden Addition8 module.
- Machine-wide trust changes without explicit approval.

## Acceptance gates

- G0: state and pins.
- Both pinned tools answer their smoke-test commands.
- `bash scripts/llzk/doctor.sh --require-llzk`.

## Handoff

- Changes made:
- Decisions made:
- Deviations:
- Blockers:
- Resulting commit:
- Exact next action: prepare S02 golden contract

