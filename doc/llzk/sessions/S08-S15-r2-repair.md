# S08–S15 — the R2 repair

Status: complete  
Depends on: R2 (`doc/llzk/review/R2-findings.md`)  
Base integration commit: `410343b2cc7fd6d4df2757b312787501eda58c17` (R2's bootstrap)  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Discharge every R2 finding and control-set item, and close the gap R2
demonstrated: nothing checks the emitted constraints.

Run as one session rather than the six R2 proposed. The groupings R2 recommended
are kept as the section structure below, and each is separable in review, but the
first four all touch `IR.lean` and the goldens, and splitting them would have
meant regenerating the same fixtures four times.

## Must read

- `doc/llzk/review/R2-findings.md`, then `review/R2-resolution.md` for the
  finding-by-finding outcome
- `doc/llzk/CURRENT.md`, `PINS.md`, `GATES.md`

## What changed

**S08 — the fail-open validations.** R2-01 is closed by construction rather than
by a check: the component is always `@Main` (D015), so there is no name to
validate. R2-02 and control S2 are checks: `ExportTable.diagnose` takes the prime
and rejects a row value at or above it, and `diagnoseRegistry` rejects a table
named `Main`.

**S09 — the harness discriminates.** `require_llzk_witgen_discriminates` runs
`llzk-witgen` on a real corpus artifact twice, and aborts unless it passes on the
expected witness and fails on a perturbed one. `Differential.inputsJson` emits
decimal strings.

**S10 — the witness-block environment.** `Analyze` threads the block's base
offset; `Witness.checkBlockLocal` refuses a cell that reads a variable its own
block allocates. A5 now holds for every accepted shape rather than for
single-cell blocks.

**S11 — IR invariants.** `Builder.component` is the only constructor of a
`StructDef` and takes one `ParamSpec` list for both functions; `Builder.fresh`,
`emit`, `emitValue` and `structNew` are private; `Module` holds one root;
`FeltBinOp` lost `sub`/`div`; `Ty` lost `Inhabited`. The renderer fixtures moved
into the library, were rebuilt on the component builder, and are now fed to
`llzk-opt` by the harness. Dead API removed.

**S12 — `@Main` and the analysis pipeline.** The root component is `@Main`,
`llzk.lang` is the string form, and G10 checks that every artifact is admissible
to `--llzk-product-program`, with the SMT lowering behind a declared-reason
tolerance list. What the pinned toolchain can and cannot do against `constrain()`
is written down, including that no solver is reachable from it.

**S13 — coverage.** 19 negative fixtures, one per rejection path. `passthrough`
and `constOut` cover D008's own shapes. Six squaring components pin all six
registry primes behaviourally.

**S14 — documentation and control plane.** Stale docstrings, counts and decision
entries corrected; D005 rewritten to claim only what is true; D011 records
R2-05's unstated side condition; D014 names `dynamicWitnesses`; D015–D017 added;
orchestration deviations recorded in `PROVENANCE.md`.

**S15 — gate G9.** `Poly.lean` and `Constraints.lean`: two readers, one for the
Clean circuit and one for the emitted module, meeting only at a canonical
polynomial form. `ofSource_eqs_iff` proves the Clean-side reader equivalent to
`ConstraintsHoldFlat`; every polynomial operation carries its evaluation theorem.
`Test/Constraints.lean` runs the comparison over the corpus and pins that it goes
red for five perturbations.

## Non-goals

- A preservation theorem about `lower` itself. G9 compares two readers on the
  corpus; the universal statement needs a simulation argument over `BuilderM`.
- Anything on the witness side of the proof track — blocked on R2-05.
- Closing D012.
- Stage-2 capability.

## Acceptance gates

```bash
export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen
bash scripts/llzk/e2e.sh
```

`PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10`, exit 0 — 11 circuits, 27 input
vectors, both witgen backends, 2 renderer fixtures.

## Evidence

- `doc/llzk/evidence/S08-S15/gates.txt` — the full run.
- `doc/llzk/evidence/S08-S15/controls.txt` — every gate added or repaired,
  shown going red: the vacuous harness (R2-06), a root that is not `@Main`
  (R2-12), and the empty `@constrain` (R2's Control 4) against G9.

## Handoff

- Changes made: every module under `Clean/Backend/LLZK/` touched; `Poly.lean`,
  `Constraints.lean`, `RendererFixture.lean` and `Test/Constraints.lean` added;
  `scripts/llzk/{e2e,lib}.sh`; `doc/llzk/{CURRENT,ROADMAP,GATES,DECISIONS,
  PROVENANCE}.md`; `doc/llzk/review/R2-resolution.md` and
  `doc/llzk/evidence/S08-S15/` added.
- Gates: all green, from this commit, reproduced above.
- Findings discharged: all 15, plus all six control-set items. Three are
  discharged by recording rather than by code and say so —  R2-05 (a side
  condition `FiniteField` cannot express), part of R2-12 (the solver is
  unreachable), and R2-15's S06 packet, which is recorded as a deviation rather
  than back-dated.
- New decisions: D015 (`@Main`), D016 (`llzk.fields` and `llzk.lang`),
  D017 (checking constraints by comparing polynomials). D005, D006, D008, D009,
  D011, D012 and D014 amended.
- New gates: G9 (the emitted constraints) and G10 (the LLZK analysis pipeline).
  `GATES.md` states what each does not establish.
- Resulting commit: **not committed by this session.** The worktree carries the
  change; `git status` and the diff are the record until a commit is made.
- Exact next action: **R3**, a review of this repair. It touched every module,
  added two, and has been reviewed only by the session that wrote it. R2's own
  closing note about its method gap — verifying that each mechanism is right
  without asking what the corpus and fixtures actually *reach* — applies here at
  least as much. Start from `review/R2-resolution.md` and try to falsify it.
