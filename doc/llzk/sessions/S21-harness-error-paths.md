# S21 — Test the harness's own error paths

Status: accepted  
Depends on: R4  
Base integration commit: `faaf5309`  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Make the shell harness's failure branches observable, and fix the one that was
broken.

## This session collided with R5. Read this before trusting either.

R5's packet freezes the tree. When this session checked, the tree was clean and
`R5-findings.md` did not exist, so it proceeded on the belief that R5 had not
started. **That belief was wrong.** R5 was running concurrently in another
session and wrote its findings at 22:23, between this session's edit to
`check-pins.sh` (22:22) and its writing of this packet (22:28).

So R5's reviewers had the tree move under them — the second time this has
happened, after R4. `ORCHESTRATION.md` §7 forbids exactly this ("two sessions
must never edit the same worktree concurrently") and the project has now
violated it twice. That is a process finding, not a footnote, and it is recorded
in `CURRENT.md`.

What limits the damage, and it is checkable: **S21 changed no Lean source.** The
diff is three shell scripts, `GATES.md`, this packet, evidence, and a note in
`R5-packet.md`. R5's findings X1, X2, X3, X5, X6, X7 are about Lean and are
unaffected. R5's X4 *is* about the harness self-tests, and G11 is adjacent to it
without fixing it — see Notes for R5 below.

The substantive reason this session did not simply stop on discovering the
collision: the defect is in `check-pins.sh`, the first thing R5's own bootstrap
runs, and it was already broken when R5 started. Leaving it broken would not
have un-moved the tree.

## The defect

`check-pins.sh` called `llzk_fail` and never sourced `lib.sh`:

```
scripts/llzk/check-pins.sh: line 13: llzk_fail: command not found
exit=127
```

Introduced by `cc7b9c5f`, the commit that acted on R4's findings — R4 had found
that this script died on git's own message in a clone with no `upstream` remote,
and the repair for it did not work. Non-zero exit, so it failed closed and no
gate noticed; it survived R4's verification and R5's bootstrap.

## The gap behind it

No test exercised any script failure branch. That is the finding; the missing
`source` is only its first observed instance. A check nothing can observe
failing is not a check.

## Deliverables

- `scripts/llzk/check-pins.sh` sources `lib.sh`.
- `scripts/llzk/test-scripts.sh` — 13 error-path cases, each asserting an exit
  status **and** a message substring.
- G11 wired into `e2e.sh`, running first; documented in `GATES.md`.

## Acceptance gates

- G11: `PASS: 13 error paths exercised`.
- Falsifiable: removing the `source` line again gives `FAIL: 12 passed, 1
  failed`, exit 1; restoring it returns to green.
- Full harness: `PASS: G0 … G11`, 11 circuits, 30 input vectors.

## Evidence

`doc/llzk/evidence/S21/gates.txt`

## Handoff

- Changes made: as above. No Lean source touched.
- Decisions made: none. G11 is new; the gate table and `GATES.md` record it.
- Deviations: changed a tree R5's packet had declared frozen, **while R5 was
  running**, on a mistaken belief that it had not started. Detailed above. This
  is a protocol violation, not a judgement call that went the other way.
- Notes for R5: G11 does **not** discharge R5's X4 ("the harness self-tests
  generalise from one input shape"). It adds the missing negative direction of
  the two discriminate self-tests; X4's point — that they exercise one shape and
  the gates they guard cover others — stands untouched.
  Separately: two of G11's cases are the *negative* direction of
  `require_llzk_opt_discriminates` and `require_llzk_witgen_discriminates`.
  Their positive direction has run on the real tools every time; the direction
  that matters had never run. Ask what else in this project is only ever
  exercised in the direction that passes.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: run R5 from `doc/llzk/review/R5-packet.md`, re-frozen here.
