# S24 — Finish Stage 1: close X1, and make the evidence reproducible

Status: proposed  
Depends on: R5 and its repairs (all landed), S23 (specified, not executed)  
Base integration commit: `bd179901`  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Retire the four items that stand between the current tree and a Stage 1 that a
stranger could reproduce and believe. In order, because each makes the next
safer.

## The worktree is free — claim it before writing

Verified at 01:25 on 2026-08-02: clean tree, no Lean build running, lock free,
last modification an hour earlier. Do not skip the claim on the strength of that
sentence. S21 checked the same way, concluded R5 had not started, and was wrong
because "clean tree, no findings file" is not a lock and the answer went stale
between reading and acting. That was the second of three collisions in one day;
see `doc/llzk/CONCURRENCY.md`.

```bash
bash scripts/llzk/worktree-lock.sh claim "S24 finish Stage 1"
```

## Deliverable 1 — wire the lock into `e2e.sh`

One line, first, because it protects everything after it:

```bash
bash "${script_dir}/worktree-lock.sh" require
```

at the top of `e2e.sh`, before G11.

It was deliberately not wired when written: doing so would have failed the gate
run of a session that was mid-repair and had claimed nothing. That session has
finished, so the objection is gone.

Consequence to accept knowingly: **every** future gate run must claim the lock
first, including CI. Give CI a claim step, or have `require` treat a
non-interactive environment as exempt — decide which, and write down why in
`CONCURRENCY.md`. Do not leave CI silently red.

Add an error-path case to `test-scripts.sh` for the new refusal, so G11 covers
it the way it covers every other branch.

## Deliverable 2 — execute S23, closing X1

`doc/llzk/sessions/S23-x1-closure.md` has the design: `CertifiedConfig F`
carrying the proofs to the seven public entry points, which stop accepting a
plain `Config`. It is implementation, not design — the signatures and call sites
are enumerated there, and `verify` has been added to the table since.

Re-verify the enumeration against the tree before starting: S23 was written at
`07c8cd77` and four commits have landed since, at least one of which
(`10fddf86`, X3) changed this surface.

X1 is *confined* today and this makes it *closed on the supported path*. What it
does not do is tie an `ExportTable` to the circuit's own `Table` — the caller
still picks both sides of `Certifies`. That half needs `RawTable` to stop erasing
the `Table`, which is a Clean-core change with its own review.
`GAPS.md` §1 now states the split correctly; keep it that way.

## Deliverable 3 — reproduce from a clean checkout

Never done. R2's exit criterion required it and every review since has inherited
the omission. Everything green so far has been green on *this* worktree, which
has accumulated a `.lake`, a Nix store, and an `upstream` remote that a stranger
will not have.

```bash
git clone --no-local . /tmp/llzk-clean-checkout
cd /tmp/llzk-clean-checkout
git remote add upstream git@github.com:Verified-zkEVM/clean.git
# then the documented path, from doc/llzk/CURRENT.md, and nothing else
```

Record every step that was needed but not documented. Those are the findings —
the point is not that the gates pass, it is what a stranger has to discover.
Expect the mathlib build to dominate the wall clock; that is the cost of the
gap, not a reason to skip it.

## Deliverable 4 — CI, which needs your authorization

`262c9684` added `llzk-harness` and `llzk-e2e` and said plainly that the jobs
have never run on GitHub. Until they do, the LLZK gates are still one-machine
and the CI file is untested code.

`ORCHESTRATION.md` §11 reserves publishing a branch for explicit authorization.
**Stop and ask before pushing.** If authorization is withheld, say so in the
handoff and leave the CI jobs marked unrun — do not quietly relabel them as
working.

## Acceptance gates

- G0–G12 green, from the uncontested worktree, at the resulting commit.
- G11 covers the new lock refusal.
- G12 still green and still falsifiable.
- Deliverable 3's clean-checkout run reaches the same `PASS` line, or its
  divergences are recorded as findings.
- No new `sorry`, no new axioms.

## What to claim afterwards, and what not to

Afterwards it is true that the supported entry points cannot emit a module with
uncertified tables, and that the gates reproduce from a clean checkout.

It is **not** true that the emitted lookup constraints are sound in general
(`GAPS.md` §1, second half), that the renderer is faithful (§2), that there is a
chain to a gadget's `Spec` (§3), or that D017's reading of LLZK has any formal
basis (§7). Stage 1 closing does not close those, and `GAPS.md` stays the
register.

Write the weaker claim. Every review from R2 to R5 was provoked by this project
writing the stronger one.

## Handoff

Status: **executed**. Deliverables 1–3 are done; 4 is blocked on authorization
that was requested and not given, and is recorded as unrun rather than relabelled.

**Changes made.**

- *D1* (`a64bb4ba`) — `e2e.sh` requires the worktree lock before G11. G11 gained
  ten lock branches, 20 error paths → 30. CI's `llzk-e2e` job claims the lock.
- *D2* (`ccfddd8d`) — `CertifiedConfig F` at all seven public entry points;
  `Config.ofCertified` retired; new `Certificate.lean`; `GAPS.md` §1 first half
  closed.
- *D3* — `evidence/S24/clean-checkout.md`, plus the two documentation repairs it
  justified: `CURRENT.md`'s reproduce block and `check-pins.sh`'s diagnostic.

**Decisions made.** D023, recording three: that `e2e.sh` is the right place for
`require`; that CI claims rather than being exempted; and that `reclaim` is split
out of `claim`.

**Deviations.** Two, both enlargements of D1 rather than departures from it, and
both forced by the same discovery — that the lock did not work for agent
sessions. The packet called D1 "one line". It is one line plus a repair to the
thing that line was about to start enforcing; wiring in a check that is broken
for the sessions it protects would have been worse than leaving it unwired. D2
also grew a file split (`Certificate.lean`) that S23 did not anticipate, for the
layering reason recorded in D022.

**Authorization requested / granted.** Requested for D4; **not granted** — no
answer was given. Nothing was pushed. The `llzk-harness` and `llzk-e2e` jobs have
still never run on GitHub, and `CURRENT.md` now says so where it previously
implied they ran on every pull request.

A fact the packet did not have, which changes what D4 is worth: `ci.yml` triggers
on `push` to `main`, `pull_request` and `workflow_dispatch`. **Pushing
`clean-to-llzk/integration` would run nothing.** The jobs need a pull request. So
the choice is not "push or not" but "open a PR on the fork, or accept that the CI
configuration stays untested".

**Clean-checkout findings.** Four; the file has them in full.

1. `lake exe cache get` is documented nowhere, so the documented path builds
   mathlib from source. Invisible from both places it would have been caught —
   the dev worktree has had a `.lake` since S00, and CI does the step implicitly
   through `lean-action`. **Fixed.**
2. `git remote add upstream` is required by G0 and documented only as a URL; the
   diagnostic said what was wrong, not what to do. **Fixed.**
3. `CURRENT.md` exports a bare `/nix/store` path before pointing at `PINS.md`.
   Recorded, not fixed.
4. `ByteDecomposition/Theorems.lean:62` is a `bv_decide`, so G1 can go red under
   machine load with the tree correct. Observed, then succeeded on retry with
   nothing changed. Recorded, not fixed — pinning a solver budget is a change to
   Clean.

The headline is that **nothing in the tree had to change** for a fresh checkout
to reach the same `PASS`. All four findings are about the instructions.

**Resulting commit.** See `evidence/S24/gates.txt`.

**Exact next action.** Decide D4. If a PR is authorized, open it from
`clean-to-llzk/integration` on the fork and report what the two jobs do —
expecting the claim step to be the first thing either has ever exercised outside
this machine. If it is not, the next packet is `GAPS.md` §1's second half (the
Clean-core change carrying `Table` into `Lookup`), which is the largest remaining
soundness gap and is upstream of this backend.
