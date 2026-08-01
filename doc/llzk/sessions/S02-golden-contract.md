# S02 — Validate the emitted corpus against the pinned tools

Status: accepted  
Depends on: S01, S07  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Establish G3–G7 against the pinned LLZK 3.0 tools.

## Deviation from the planned objective

The packet as written called for a *handwritten* `Addition8FullCarry.llzk` to
freeze as the contract, on the assumption that S02 would run before any emitter
existed. By the time the tools were available, the emitter existed and produced
that module, so the handwritten fixture would have been a second source of truth
to keep in sync with no added assurance. S02 validated the emitted corpus
instead.

The risk that reordering created — five increments of syntax read from fixtures
rather than confirmed by tools — is now retired, and it cost nothing:
`Print.lean` needed no change.

## Deliverables

- `Clean/Backend/LLZK/Differential.lean` — Clean's witness, rendered in the shape
  `llzk-witgen --check-output` compares against.
- `Clean/Backend/LLZK/Corpus.lean` — circuits plus their input vectors.
- `EmitMain.lean` writes the inputs and expected witnesses alongside the modules.
- `scripts/llzk/e2e.sh` runs G3–G7.

## Acceptance gates

`PASS: G0 G1 G2 G3 G4 G5 G6 G7` — 3 circuits, 16 input vectors, both witgen
backends. Evidence: `doc/llzk/evidence/S02/gates.txt`.

## Handoff

- Changes made: as above, plus `Circuit.lean`'s layout-name functions made public
  so the differential harness keys its JSON on exactly the emitter's names.
- Decisions made: D014.
- Deviations: as above. Also `Corpus.lean` is separate from `Examples.lean`
  because importing `Clean.Circuit.WitnessGeneration` into the latter changes
  what `elaborate_circuit` sees and the example circuits then fail to elaborate.
- Blockers: none.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: R2 (Stage-1 acceptance review from a clean checkout), then
  S08 (proof baseline). The largest remaining assurance gap is that nothing
  checks the emitted *constraints* — `llzk-witgen` ignores `constrain()`.
