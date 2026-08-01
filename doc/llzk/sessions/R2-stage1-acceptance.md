# R2 — Stage-1 adversarial acceptance review

Status: proposed  
Depends on: S02 (all of S00–S07 accepted)  
Base integration commit: `a0c862786691a3bbdbbb2543c98ceb0951a9f24d` — verify with `git rev-parse HEAD`  
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

- Changes made:
- Verdicts: (counts of REFUTED / CONFIRMED / UNSUPPORTED / NOT-CHECKED)
- Findings and their severity:
- Control-set coverage:
- Decision: accepted / returned for repair
- Follow-up packets written:
- Resulting commit:
- Exact next action:
