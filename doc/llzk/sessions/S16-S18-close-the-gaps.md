# S16–S18 — close the three gaps the R2 repair documented

Status: complete  
Depends on: S08–S15 (`sessions/S08-S15-r2-repair.md`), R3 (`review/R3-findings.md`)  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

`review/R2-resolution.md` originally ended with a list of three things the repair
had *not* done. Recording a gap instead of closing it is the failure R2
criticised, so: close them.

## What changed

**R3 first.** Reviewing the repair before extending it found three defects in
S15's own code — a vacuous guard in `ConstraintSet.ofModule`, a `global.read` of
an undefined name accepted, and a falsifiability control set with no
wrong-table case. All fixed. It also found that `Poly.lean` *understated* its
own normal form, which is now pinned. `review/R3-findings.md`.

**S16 — D012's lookup rows, proved.** The trust assumption was one sentence, and
one sentence can be a `Prop`. `ExportTable.Certifies` is it, stated over
`rows.flatten` because that is exactly the value list `Circuit.lower` emits.
`ofStatic_certifies` discharges it for any single-column `StaticTable`;
`byteTable_certifies` for `Gadgets.ByteTable`, the case D012's follow-up called
open. It turned out not to need `ByteTable`'s `StaticTable` to be named:
`StaticTable.toTable` defines `Contains` from the `row` function alone, and
`contains_iff` already relates that to `x.val < 256`.
`certified_membership` is the bridge to the emitted array, and it is where S08's
range check does its work.

**S17 — G9 for every circuit, not the corpus.** `ConstraintSet.agree` is
decidable, so the emitter runs it on its own output and refuses to return a
module that fails. `compile` and `emit` moved out of `Circuit.lean` into
`Constraints.lean` so that they go through it and there is no unchecked path.
`agree_of_compileSource'` is the theorem; `eqs_iff_of_compileSource'` and
`lookups_perm_of_compileSource'` give it meaning. Recorded as D018, including
what translation validation trades away against a verified translator.

**S18 — R2-05's field law, enforced.** `LLZK.CanonicalRepr` carries the two laws
that pin `FiniteField.val` to the ring representative, `val_natCast` shows they
do pin it, and every recognizer and entry point requires the class — so a field
that lacks it is a type error. Recorded as D019.

## Non-goals

- A preservation theorem about `lower` itself (the `BuilderM` simulation
  argument). D018 records why translation validation was taken instead, and
  `CURRENT.md` keeps it open as S20.
- The witness side of the proof track. Now *unblocked* by S18 rather than
  blocked, and left to S19.
- Making `Config.tables` demand a certificate. Needs the `Table` that `RawTable`
  erased; recorded as a residual.

## Acceptance gates

```bash
export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen
bash scripts/llzk/e2e.sh
```

`PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10`, exit 0.

## Evidence

- `doc/llzk/evidence/S16-S18/gates.txt` — the full run.
- `doc/llzk/evidence/S16-S18/proofs.txt` — the axiom check over every theorem
  added by S15–S18, and the canonicity stress test R3 ran.
- `doc/llzk/evidence/S08-S15/controls.txt` — still current: the gates added by
  the repair, shown going red.

## Handoff

- Changes made: `Clean/Backend/LLZK/{Field,TableCert}.lean` added;
  `Constraints.lean` gained the verified entry points and three theorems;
  `Circuit.lean` lost `compile`/`emit` to it; `CanonicalRepr` threaded through
  `Expression`, `Witness`, `Analyze`, `Circuit`, `Differential`, `Corpus`;
  `Table.ofStatic` reimplemented over `List.finRange` so its membership lemma is
  a structural induction; docs and `review/R3-findings.md`.
- Gates: all green, reproduced above.
- New theorems, all with axioms `[propext, Classical.choice, Quot.sound]` and no
  `sorry`: `ofStatic_certifies`, `byteTable_certifies`, `certified_membership`,
  `agree_of_compileSource'`, `eqs_iff_of_compileSource'`,
  `lookups_perm_of_compileSource'`, `CanonicalRepr.val_natCast` (which needs only
  `propext` and `Quot.sound`).
- New decisions: D018 (validate every translation), D019 (require
  `CanonicalRepr`). D011 and D012 amended: both now record their assumption as
  discharged rather than open.
- Resulting commit: **not committed by this session.** The worktree carries the
  change; `git status` and the diff are the record until a commit is made.
- Exact next action: **R4**, an independent review. S16–S18 are new code reviewed
  only by the session that wrote them, and R3 shares that defect. Start from
  `review/R3-findings.md` § "What R3 did not do".
