# S27 — Upstream the zkGolf-optimised gadgets onto the fork, and re-pin

Status: **returned for re-scoping by R7 — do not execute as written**
Depends on: S25 (landed) and S26 (landed). ~~Doing this before S26 produces
gadgets the backend still refuses — see "Why last"~~ — false, see below.
Base integration commit: S26's resulting commit
Worktree: **a second worktree.** This is a Clean-side change; see "Where".
Branch: `clean-gadgets/zkgolf` off `alexanderlhicks/clean` `main`

## R7: three of this packet's premises are false (R7-09)

Checked against `~/zkgolf` itself; `review/R7-findings.md` has the evidence.

1. **The field is GF(2), not bn254.** `submission_gf2`'s circuits are over
   `p2 := 2` (`Challenge/Utils/F2Bits.lean:17`); `circomPrime` = bn254 belongs
   to the *SHA256* challenge, not this submission. GF(2) is not in
   `FieldSpec.registry` and is not an LLZK registry field, so Deliverable 3
   ("corpus entry … the easy case for S26's lowering") is unimplementable as
   written: the ported gadgets cannot become corpus entries at all without an
   LLZK-side field that does not exist.
2. **There are no bitwise operations to wait for.** Over GF(2), xor is `+` and
   and is `*`; the submission uses native-closure witnesses of embedded field
   expressions — zero `lxor`/`land`, zero `Witgen` usage, zero bit
   decompositions. The claimed dependency on S26 does not exist.
3. **The real blocker is `Step.letF`, which S26 excludes.** The Add32 gadgets
   witness 31 carries through the recursive `carryVal`; a `VExpr.lit` inlining
   of that recurrence doubles per bit (~2^31 terms), so the faithful IR port
   needs `letF` chains — refused today, and a non-goal of S26. The tops are
   also `GeneralFormalCircuit`, for which `Compilable` has no instance. As
   written, this session's ported gadgets would not be exportable even after
   S26 lands.

**What survives:** the port itself (Deliverables 1–2 — the gadgets onto the
fork, the pin advance, the `computableWitnesses` proof archaeology across 203
upstream commits) is still real and still a Clean-side session under
ORCHESTRATION §11. But its *backend* payoff needs a decision first: either an
export story for GF(2) (an LLZK field question, not a Clean one), or re-target
the port at gadgets the backend can host (bn254 material from the SHA256
challenge — noting `axiom hCircomPrime` in that challenge's interface, which
would fail the axiom gate), or run the port purely as library work with no
corpus claim. Re-scope before executing; do not inherit this packet's
acceptance criteria.

## Objective

Port the cost-optimised circuits from `~/zkgolf/submission_gf2` onto current
Clean in the fork, against the post-S25 witness IR, and advance this project's
pinned base to include them.

## Must read

- `doc/llzk/DECISIONS.md` — D002 (the fork is the project home), D012's follow-up
  and `GAPS.md` item 8, both of which argue *from* Clean-core byte-identity
- `doc/llzk/ORCHESTRATION.md` §11
- `doc/llzk/ROADMAP.md` §"Measured coverage of Clean's gadget library"
- `~/zkgolf/llms.txt` — the platform's own constraints

## Why last

zkGolf circuits are Clean circuits, so this looks like the shortest path to real
test material. It is not, for a reason worth stating before anyone reorders it:

**a zkGolf gadget ported to current Clean is still bitwise.** `submission_gf2` is
a GF(2) SHA-256 compression — Add32, Ch32, Maj32, rounds, schedule. Every one of
those needs `land`/`lxor`. Port them before S26 and the backend refuses them,
which means porting proofs to a compiler that cannot emit the result.

## The facts, measured, so a fresh session does not rediscover them

Verified 2026-08-04:

| | value |
|---|---|
| zkGolf's Clean pin | `041c6e7e`, 2026-06-04 |
| zkGolf's toolchain | `leanprover/lean4:v4.28.0` |
| witness IR at that pin | **does not exist** — `Clean/Circuit/` has no witness-IR module, and `witnessVector` takes `ProverEnvironment F → Vector F m`, the native closure form, as its *only* form |
| witness IR landed | `0318a68e`, 2026-06-10 — **six days after** zkGolf's pin |
| fork `main` | `1e563b9c` — *exactly* this project's `clean_base` before S25 |

Two consequences.

**Porting the witness generators "to the IR at zkGolf's pin" is impossible.** There
is no IR there. A newer Clean is not one option among several; it is the only
route to exportability, which is what makes this session a port rather than a
translation.

**Bumping zkGolf's own pin is not available to you.** Their documentation:
*"Changing or upgrading [Clean] forces a full rebuild inside the sandbox that will
exceed the verifier timeout, so your submission will time out."* That is a
platform decision for zksecurity. This session therefore produces **gadgets in the
fork**, not submissions — and the ported gadgets will not score on zkGolf.

## Where

Not in this worktree, and not on `clean-to-llzk/integration`. G0 fails on any
change to `Clean/` outside `Clean/Backend/LLZK/`, and that gate is the reason this
is a separate session rather than a convenience:

```bash
git worktree add -b clean-gadgets/zkgolf ../clean-gadgets origin/main
```

## Deliverable 1 — port, additively only

Port `~/zkgolf/submission_gf2`'s circuits into `Clean/Gadgets/` under **their own
directory** — new files only, and **no edit to any existing Clean file** except
the `Clean.lean` import line.

This is not tidiness. Clean moved 133 commits between zkGolf's pin and
`1e563b9c`, and another 70 to `0e53b9f2` — roughly a hundred commits a month.
Additive-only makes every future upstream merge trivial and makes the eventual
PR to `Verified-zkEVM/clean` a file-add rather than an archaeology exercise. A
fork that edits Clean's core is a fork you maintain forever.

What has to change in the port, beyond mechanical renaming:

- **`witnessVector 7 fun env => …` → the witness IR.** Every native closure
  becomes a `VExpr`. The bit decompositions are the interesting ones and after
  S25 they are `VExpr.bitsOf`, not a hand-rolled shift-and-mask.
- **`GeneralFormalCircuit` vs `FormalCircuit`.** zkGolf's tops are
  `GeneralFormalCircuit`; this backend's `Compilable` instance covers
  `FormalCircuit` only. Adding the second instance is small — same
  `main`/`operations` shape — and belongs in `Clean/Backend/LLZK/Circuit.lean`,
  so it is a *backend* change on `integration`, not part of this branch.
- **zkGolf's cost infrastructure does not come along.** `Challenge.CostR1CS`,
  `CostIs`, `operationsIsR1CS`, `Affine` are platform-local. Port the circuits and
  their soundness/completeness proofs; drop the cost certificates, or reconstruct
  them only if Clean gains an equivalent.
- **Attribution.** `submission_gf2` is the operator's own work. Other people's
  winning submissions are not yours to upstream — if any are wanted, that is a
  permission question to settle with their authors first, not a technical one.

## Deliverable 2 — advance the pin

Once the gadgets are on fork `main`:

- `scripts/llzk/check-pins.sh`: `clean_base` → the new fork-`main` commit.
- Bring `clean-to-llzk/integration` onto it.
- G0's byte-identity check then means what it has always meant — *this branch adds
  only `Clean/Backend/LLZK/`* — measured against a base that now contains the
  gadgets.

## Deliverable 3 — put them in the corpus

A ported gadget that only compiles is not validated. At least one of the ported
circuits becomes a corpus entry with input vectors, so `llzk-opt` and both witgen
backends see it, and re-measure the coverage table.

The field is `circomPrime` = **bn254**, already in `FieldSpec.registry` with the
right prime — and, per S26's width analysis, the one field that holds a `u64`
outright. That makes these circuits the easy case for S26's lowering rather than
the hard one, which is a second reason they belong after it and not before.

## Non-goals

- A PR to `Verified-zkEVM/clean`. The fork is the staging area; upstreaming
  further is a separate decision, and worth making deliberately, because staging
  areas become permanent.
- Any zkGolf submission. Their verifier uses their own pin.
- Editing Clean's core. If a port seems to need it, stop and record why — that is
  a finding about Clean, not a licence to widen this session.

## Acceptance gates

- Fork branch: `lake build --wfail Clean` and `lake build CleanTests` green on
  Lean 4.32.2.
- After re-pinning: all twelve gates on `integration`, with G0 green against the
  **new** base and the corpus counts raised.
- Re-measured coverage table.

## Evidence

`doc/llzk/evidence/S27/`: `gates.txt`, `port-notes.md` (what each native witness
closure became, and anything that could not be ported and why), `coverage.md`.

## Handoff

- Changes made:
- Decisions made:
- Deviations:
- Blockers:
- Resulting commit:
- Exact next action:
