# S19 — the witness side of G9, and the last two residuals

Status: complete
Depends on: S16–S18 (`sessions/S16-S18-close-the-gaps.md`)
Worktree: `/home/alh/LLZK/clean-llzk-frontend`
Branch: `clean-to-llzk/integration`

## Objective

`CURRENT.md` listed the witness side as the largest remaining gap: `@compute`
rested on G5–G7 differentially and on nothing else. S18 made its preservation
theorem *statable*; this states it, and closes the two smaller residuals beside
it.

## What changed

**The witness half of G9.** `Clean/Backend/LLZK/WitnessCheck.lean` reads the
Clean circuit's witness programs and the emitted `@compute` into a common tree
language and compares them, and `WExpr.eval_ofWitgen` proves the Clean-side
reading is `Witgen.FExpr.eval`. A tree rather than a polynomial because
`felt.umod`/`felt.uintdiv` are not polynomial; see D020. The comparison is a
precondition of emission alongside the constraint one, so `compile` and `emit`
moved to this module and go through both.

**Table certificates are required, not merely available.** `Config.ofCertified`
takes `CertifiedTable`s — an `ExportTable` with its proof — and `withBytes` uses
it, so the corpus's only lookup table carries its certificate by construction.

**Three out-of-assumption vectors** for `Addition8FullCarry`: `x` above a byte,
a non-boolean carry-in, and both inputs near `p`. R2's C5 recorded that nothing
tested the gadget outside its `Assumptions`. The gadget's `Spec` says nothing
there, but the two witness generators must still agree, and they do.

## Non-goals

- The whole-vector statement: that the emitted `@compute` produces exactly
  `FlatOperation.dynamicWitnesses`. That needs the block-prefix argument R2-03 is
  about, which `Analyze` enforces rather than proves.
- A preservation theorem about `lower` (still S20).

## Acceptance gates

```bash
export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen
bash scripts/llzk/e2e.sh
```

`PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10`, exit 0 — 11 circuits, 30 vectors.

## Evidence

`doc/llzk/evidence/S19/gates.txt`, and the axiom check in
`doc/llzk/evidence/S16-S18/proofs.txt` extended with the two new theorems.

## Handoff

- Changes: `WitnessCheck.lean` and `Test/WitnessCheck.lean` added; `compile`/
  `emit` moved there from `Constraints.lean`; `TableCert.lean` gained
  `CertifiedTable`/`Config.ofCertified`; `Corpus.lean` gained `witnessAgree` and
  three vectors; docs.
- New theorems, no `sorry`: `WExpr.eval_ofExpression`, `WExpr.eval_ofWitgen`,
  `witnessAgree_of_compileSourceVerified`,
  `constraintsAgree_of_compileSourceVerified`.
- New decision: D020. D012 amended (the certificate is now required).
- Exact next action: reconcile the findings of the two independent reviews
  running against this tree (R4), then Stage 2.
