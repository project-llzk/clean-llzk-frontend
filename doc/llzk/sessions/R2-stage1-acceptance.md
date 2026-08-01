# R2 — Stage-1 adversarial acceptance review

Status: proposed  
Depends on: S02 (all of S00–S07 accepted)  
Base integration commit: `0f4f5705a22980524afba1ec4ae724e2f4646a4e` — the commit
this packet reviews, i.e. `git rev-parse HEAD^` from the commit that added the
packet. (Corrected by S14 per R2-15: the packet originally named a third value,
`a0c86278`, and said to verify it with `git rev-parse HEAD`, which cannot hold at
the commit that introduces the packet.)  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Decide whether Stage 1 is accepted, by trying to falsify it. One observable
outcome: a written verdict on every claim in `doc/llzk/review/CLAIMS.md`, plus
any finding not covered by a claim.

This is **not** a read-through. The implementation and its own tests were written
by the same session; that session's confidence is not evidence. Assume something
is wrong and go looking for it.

## Start read-only

Change nothing until the review is written down. If a fix is obvious, record it
as a finding first — a review that starts editing stops reviewing.

## Bootstrap

```bash
cd /home/alh/LLZK/clean-llzk-frontend
git rev-parse --abbrev-ref HEAD          # expect clean-to-llzk/integration
git status --short                       # expect empty
bash scripts/llzk/check-pins.sh

export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen
bash scripts/llzk/doctor.sh --require-llzk
bash scripts/llzk/e2e.sh                 # expect PASS: G0 G1 G2 G3 G4 G5 G6 G7
```

If the tools are absent, `PINS.md` has the acquisition command and the
cache-key requirement. Note that `nix-daemon` must have been restarted since
`/etc/nix/nix.conf` last changed.

## Must read

In this order:

1. `doc/llzk/review/CLAIMS.md` — the claim inventory. This is the work list.
2. `doc/llzk/CURRENT.md` — including its "What is still not established" section.
3. `doc/llzk/DECISIONS.md` — D001–D014.
4. `doc/llzk/ARCHITECTURE.md` §4–§6 — what was specified, to compare against what
   was built.
5. The backend: `Clean/Backend/LLZK/` — 14 modules, ~2065 lines. Small enough to
   read exhaustively; do that rather than sampling.
6. The emitted artifacts: run the emitter, then read `.lake/llzk/*.llzk` as text.

**Do not read** `doc/llzk/review/CONTROL-SET.md` until the review is written.
It exists to measure this review's coverage and reading it first defeats that.

## Where the value is

Ranked by expected yield, because review effort is finite:

1. **§A of `CLAIMS.md` — soundness of the emitted constraints.** No automated
   gate covers any of it: `llzk-witgen` executes `compute()` and ignores
   `constrain()`, so all 16 passing input vectors say nothing about whether the
   constraints are right. Hand-evaluate `Addition8FullCarry`'s emitted
   `@constrain` against the gadget source. This is the one place a real soundness
   bug could be hiding behind a green harness.
2. **§B — the D011 natural division/modulo argument.** Prose, not proof, and the
   most load-bearing prose in the project.
3. **§D — fail-closed completeness.** Enumerate the source constructors; find one
   that is neither accepted-with-a-fixture nor rejected-with-a-diagnostic.
4. **§C — what the gates establish.** Try to make `e2e.sh` pass vacuously.
5. **§E, §F** — design, quality, control-plane integrity.

## Allowed scope

Read-only, plus:

- `doc/llzk/review/R2-findings.md` (new) — the verdicts and findings.
- `doc/llzk/evidence/R2/` (new) — commands, output, exit statuses.
- `doc/llzk/sessions/R2-stage1-acceptance.md` (this file) — Handoff only.

Fixes belong in follow-up sessions, one per finding or per tightly related group,
so that each is reviewable against the finding that motivated it. If a finding is
a soundness bug, that follow-up is the next thing the project does.

## Acceptance gates

- G0–G8 re-run from the recorded commit, not trusted from `evidence/`.
- Every claim in `CLAIMS.md` has a verdict.
- The falsifiability controls in `evidence/S02/gates.txt` re-run, plus at least
  one new one.
- `CONTROL-SET.md` read last, and its coverage gap recorded.

## Exit

Stage 1 is **accepted** only if:

- no claim in §A is refuted or left `UNSUPPORTED` without an explicit decision to
  accept the gap;
- every other refuted claim has a follow-up session packet written;
- the review could reproduce the gates from repository files alone.

Otherwise Stage 1 returns to a narrowly scoped repair session, and this packet
records which.

## Handoff

- Changes made: `doc/llzk/review/R2-findings.md` (new) and
  `doc/llzk/evidence/R2/` (new: `e2e-reproduced.txt`, `controls.txt`). No source
  file touched; the review stayed read-only as the packet requires.
- Verdicts: 12 CONFIRMED, 8 REFUTED, 6 CONFIRMED-with-caveat, 4 UNSUPPORTED,
  0 NOT-CHECKED. Refuted: A5, C6, D2, D3, D4, E1 (D005), E2, E3, E4, F1, F4.
- Findings and their severity: 15 numbered findings, R2-01 … R2-15.
  High: R2-01 (component name never validated → invalid MLIR, no diagnostic),
  R2-02 (table row values never range-checked → silently reduced mod p),
  R2-06 (`e2e.sh` reports PASS with `llzk-witgen` replaced by `exit 0`).
  Medium-high: R2-03 (the lowering's witness environment is more permissive than
  Clean's `dynamicWitnesses`; the only §A refutation), R2-04 (D005 overclaimed,
  and `Test/Print.lean`'s golden is invalid LLZK), R2-12 (emitted modules cannot
  enter any LLZK pipeline because the root is not named `@Main`; an SMT-based
  partial constraint check was available and unevaluated).
  The most important single result is a control, not a code defect: an
  `Addition8FullCarry` with a **completely empty `@constrain`** passes G3–G7 on
  all six vectors.
- Control-set coverage: 2 of 6 found independently (S1, S3); missed S2, S5, and
  the framing of S4 and S6. All four re-checked afterwards — S2 is a real defect
  and folds into R2-01's fix; S5 and S4 are corpus gaps, not defects; S6 is a
  non-issue with a documentation point. Two of the misses share one method gap,
  recorded at the end of `R2-findings.md`: acceptance paths were never enumerated
  for coverage the way rejection paths were.
- Decision: **returned for repair.** No emitted artifact in the corpus is
  unsound — `Addition8FullCarry`'s constraints were hand-evaluated and are exactly
  the gadget's three — but the fail-closed property is refuted by two working
  counterexamples, and the harness can be made to pass vacuously.
- Follow-up packets written: none yet; six are specified with their groupings and
  ordering in `R2-findings.md` § "Recommended follow-up sessions" (S08 fail-open
  checks → S09 harness → S10 witness environment → S11 IR invariants →
  S12 SMT track → S13 documentation), with G9 after S10 and S12.
- Resulting commit:
- Exact next action: write and run **S08** — add `isSymbolName` (plus a
  table-name collision check) to the component name, and a value-range check to
  `ExportTable.diagnose`, each with a negative fixture. Both are one-loop changes
  and both break the fail-closed property that everything else rests on.

Out of scope for this packet and therefore not done: `CURRENT.md`, `ROADMAP.md`
and `DECISIONS.md` still describe Stage 1 as complete and still carry the
miscounts in R2-11. Correcting them belongs to the session that acts on the
verdict.
