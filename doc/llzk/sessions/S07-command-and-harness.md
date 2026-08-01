# S07 — Emitter command and conformance harness

Status: accepted  
Depends on: S06  
Base integration commit: `1c1cf413`  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

One documented command emits the corpus; one documented command runs every
conformance check that exists, and fails closed when it cannot.

## Deliverables

- `Clean/Backend/LLZK/Examples.lean` — the example circuits and `corpus`, shared
  by the golden tests and the emitter so they cannot drift.
- `Clean/Backend/LLZK/EmitMain.lean` — writes one `.llzk` per corpus entry.
- `scripts/llzk/lib.sh` — the tool check, shared by `doctor.sh` and `e2e.sh`.
- `scripts/llzk/e2e.sh` — pins, tools, Lean gates, emit, `llzk-opt` parse and
  round trip.
- `GATES.md` documents both commands.

## Non-goals

- G5/G6/G7. They need a per-circuit input corpus and a Clean-side witness
  comparison. `e2e.sh` states that it does not claim them.

## Acceptance gates

- G1: PASS.
- Emitter produces all three artifacts: PASS.
- Fail-closed behaviour of `e2e.sh` and `doctor.sh`: PASS, including rejection
  of the installed LLZK 2.0 binary by version.
- G3/G4: implemented, never run — no pinned tool.

## Evidence

`doc/llzk/evidence/S07/gates.txt`

## Handoff

- Changes made: circuits moved out of the test module into
  `Clean/Backend/LLZK/Examples.lean` so the goldens and the emitter share one
  definition; new `EmitMain.lean`; `lib.sh` factored out of `doctor.sh`;
  `e2e.sh` added; `GATES.md` extended.
- Decisions made: none new; two choices worth recording in the packet —
  - **No `lean_exe`.** A `lean_exe` was added, built, and removed: it forces
    native compilation of all of mathlib (~3400 extra targets). Running
    `EmitMain.lean` under the Lean interpreter needs only the oleans
    `lake build Clean` already produces.
  - **No `#emit_llzk` macro.** `#eval IO.print (LLZK.emit cfg "Name" circuit)`
    is already the interactive form, and it is what the golden tests use; the
    artifact-producing command is the emitter above. A macro would have been
    sugar over one of the two.
- Deviations: S07 ran before S01/S02, as S03–S06 did.
- Blockers: S01 still needs `sudo systemctl restart nix-daemon`.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: restart the daemon, provision the tools, then run
  `LLZK_OPT=... LLZK_WITGEN=... bash scripts/llzk/e2e.sh`. That single command is
  now S01+S02+R0's whole first step.
