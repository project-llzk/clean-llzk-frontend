# S22 — R5 X1: confine the unchecked lookup-table path

Status: accepted, with a process failure recorded  
Depends on: R5  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`  
**Landed inside commit `5b8b0b52`, which is titled for X2** — see Attribution.

## Objective

R5's X1, repair clauses 1 and 3: stop the false claim, and replace the sham
control with one that compiles with the bad config. Clause 2, "force the
certificate on the supported path", is discharged as far as it can be — see
Limits.

## What changed

`Config`'s constructor is private. The only public way to supply lookup tables
is `Config.unsafeWithTables`; `Config.ofCertified` is the wrapper that supplies
an `ExportTable.Certifies` proof, and **G12**
(`scripts/llzk/check-unsafe-config.sh`) fails if any non-test module names the
unsafe one. Recorded as D022.

`Test/Constraints.lean` now compiles *with* R5's `fatBytes` — 512 rows where
`Gadgets.ByteTable` has 256 — instead of comparing two configs production never
pairs. Two `#guard`s pin what that costs: `agree` still holds, because both
sides read `cfg.tables` and the conjunct is a tautology; and the emitted
`@Bytes` really does contain 300, which `ByteTable` does not.

The `ConstraintSet.globals` docstring, which claimed to close R4's one-row
finding, is withdrawn.

## Limits — what X1 does *not* now guarantee

The emitted module is no safer than before if someone calls
`unsafeWithTables`. Nothing ties an `ExportTable` to the `Table` a `RawTable`
erased except a proof a human writes; that is D012 and it is unchanged. What
changed is that the proof is the path of least resistance, its absence is
greppable, and a gate enforces the confinement. Calling that "X1 fixed" would
repeat the mistake R5 was created to catch, so it is not claimed.

`Gadgets.ByteTable` still cannot use `ofStatic` — it inlines its `StaticTable`
— so its certificate remains the hand-proved `byteTable_certifies`. Naming that
`StaticTable` would let it be derived and breaks every proof that unfolds
`ByteTable` with `simp`. Still open, still D012's follow-up.

## Attribution, and the process failure

This session's work is in commit `5b8b0b52`, whose message describes only R5's
X2. Another session was editing the same worktree throughout, ran `git add -A`,
and swept every S22 file into its commit — along with `R5-findings.md`.

That is the third consequence of concurrent sessions on one worktree, after R4's
reviewers losing their frozen tree and R5's losing it again during S21. The two
sessions also independently withdrew the *same* false docstring in adjacent
places, which is duplicated work with a merge hazard attached.

`ORCHESTRATION.md` §7 forbids this and the project has now violated it three
times in one day. **This is the highest-priority open item — above any remaining
R5 finding.** A code defect costs one repair; a process that lets two sessions
interleave produces misattributed history, duplicated repairs, and gate evidence
that cannot be tied to a commit, and it will keep doing so.

History was deliberately not rewritten: amending under a session that was still
active would have been worse than a wrong commit title.

## Evidence

`doc/llzk/evidence/S22/gates.txt` — gates re-run on the clean tree at
`5b8b0b52`: `PASS: G0 … G12`.

## Handoff

- Exact next action: decide the concurrency rule and enforce it before more
  repair work. R5's remaining findings are X3–X8; its repair order puts
  X3/X3b next.
