# Claim inventory for the Stage-1 adversarial review

> **Historical review input.** This inventory captures the R2-era frontend
> (14 backend modules and 16 vectors) and deliberately preserves the claims the
> early reviews tried to falsify. It is not the current release claim set. Use
> `../GAPS.md`, `../GATES.md`, and `FRONTEND-AUDIT-2026-08-22.md` for the current
> boundaries and reproduced evidence.

Every load-bearing claim the project currently makes, in one place, so a review
can try to falsify them one at a time instead of reading code hoping to notice
something.

A claim is **not** evidence that it is true. Several of these are known to be
unproven and are marked so. Treat each as a hypothesis with a stated method for
refuting it.

Reviewer: record, for every claim, one of `REFUTED` / `CONFIRMED` /
`UNSUPPORTED` (nothing establishes it either way) / `NOT-CHECKED`, with the
command or reasoning used. "It looks right" is not a verdict.

---

## A. Soundness of the emitted constraint system

The claims that matter most. If any of A1–A6 is false, the frontend is unsound
and everything else is cosmetic.

**A1.** Every Clean `FlatOperation.assert e` in the flattened circuit produces a
constraint in `@constrain` that holds iff `e` evaluates to zero.

**A2.** Every Clean `FlatOperation.lookup` produces a `constrain.in` against a
global whose contents are the table's rows, and it holds iff the queried value is
a row. *Known caveat:* D012 — the backend cannot verify the rows are the table's.

**A3.** No Clean constraint is dropped. In particular, constraints inside
subcircuits survive `Operations.toFlat`, and nothing in `Analyze` discards an
operation silently.

**A4.** No constraint is *added* that changes what the system proves. The output
equalities (D008) define fresh cells; argue this is conservative, or refute it.

**A5.** The witness-cell numbering used by the lowering (`cell k` is circuit
variable `inputSize + k`) matches Clean's actual offset allocation for every
accepted circuit shape — not only the three in the corpus.

**A6.** Reordering (D009: lookups, then assertions, then output equalities,
rather than source order) cannot change the constraint system's meaning.

**Method for A1–A6:** read `Analyze.recognizeOperation`, `Circuit.lowerConstrain`,
and the emitted `.lake/llzk/*.llzk` by hand. Hand-evaluate the emitted constraints
of `Addition8FullCarry` against the gadget's source and confirm they are the same
three constraints. Note that **no automated gate covers any of A1–A6** —
`llzk-witgen` ignores `constrain()` — so this section is entirely manual and is
the highest-value part of the review.

## B. Faithfulness of the natural division/modulo lowering (D011)

**B1.** `ofNat (mod (val x) (const c))` and `felt.umod ⟦x⟧ c` denote the same
field element, for every `x` and every `c` the recognizer accepts.

**B2.** The two side conditions (`c ≠ 0`, `c < p`) are *sufficient*, not just
necessary. Look for a case that satisfies both and still diverges.

**B3.** Matching the shape *whole* is genuinely what makes it sound — i.e. no
accepted `FExpr` reaches `umod`/`uintdiv` with a subexpression whose natural
value could have exceeded the field.

**Method:** `Clean/Backend/LLZK/Witness.lean` module docstring states the
argument; D011 records it. It is prose. Try to break it, then check whether the
corpus's input vectors would have caught what you find. If not, that is a finding
about the corpus.

## C. What the gates actually establish

**C1.** G3/G4 (`llzk-opt` parse, verify, round-trip) pass on every emitted
artifact. *Reproduce, do not trust.*

**C2.** G5/G6/G7 establish that Clean's witness generator and both LLZK backends
agree on the recorded vectors — and **nothing more**.

**C3.** The witness gates are falsifiable: a wrong Clean witness or a wrong
expected file turns the harness red. `evidence/S02/gates.txt` describes two
controls. Re-run them; devise a third they did not think of.

**C4.** G8: every rejection path has a fixture, and every fixture's message is
accurate about *why* the construct is rejected.

**C5.** The corpus's 16 input vectors exercise the boundaries that matter.
Specifically: does anything test a `umod`/`uintdiv` where the dividend's
canonical representative is near `p`? Does anything test Addition8 outside its
documented `Assumptions`?

**C6.** `e2e.sh` cannot pass while skipping a check. Try to make it pass
vacuously — remove all input vectors, empty the corpus, point `LLZK_WITGEN` at a
`true` binary in the right directory.

## D. Fail-closed completeness

**D1.** Every constructor of `Witgen.FExpr`, `VExpr`, `WitgenIR`, `Step` and
`FlatOperation` is either accepted with a fixture or rejected with a diagnostic.
Enumerate them against `Witness.lean` and `Analyze.lean`; find one that is
neither.

**D2.** No input can reach `Print` that renders to invalid LLZK. The IR is
claimed to make this unrepresentable (D005). Try to construct a counterexample —
in particular anything the *analyzer* does not check because the *IR* was
supposed to.

**D3.** Names the backend generates are always legal MLIR symbols. Table names
are checked (`Table.isSymbolName`). Check every *other* name that reaches the
output.

**D4.** `Config` cannot be set to something that produces wrong-but-accepted
output.

## E. Design and quality

**E1.** D005–D014 are each (a) actually implemented as described, (b) still the
right call. Argue against at least three of them.

**E2.** There is exactly one definition of each thing that must not drift:
layout names, the accepted subset, the field registry, the example circuits.
Find a second definition of any of them.

**E3.** No dead code, no speculative generality, no unreachable branches. The
codebase is ~2000 lines across 14 modules; this is checkable exhaustively.

**E4.** Docstrings and comments state facts that are true *now*. Several were
written before the tools ran. Find one that is stale or overclaims.

**E5.** The module boundaries hold: `IR` knows no syntax, `Print` is the only
module that does, `Basic` depends on nothing from Clean, `Analyze` is the only
capability gate.

**E6.** The Lean is idiomatic for this codebase and would pass Clean's own
review. Compare against `AGENTS.md` conventions.

## F. Control-plane integrity

**F1.** `CURRENT.md` accurately describes the state; a fresh session could
resume from repository files alone. *Test this by actually doing it.*

**F2.** Every session packet's Handoff matches what its commit actually did.
Diff the claims against `git show`.

**F3.** Evidence files record what was actually run, and their numbers match a
re-run.

**F4.** The deviations recorded (S03–S07 running before S01/S02; S02 dropping
its handwritten fixture; the reverted `ByteTable` refactor) are complete — no
undocumented deviation exists.

**F5.** No result the project depends on exists only outside the repository.

## G. Scope facts (established, for orientation — not claims to check)

- Backend source: 14 modules, ~2065 lines including tests, all under
  `Clean/Backend/LLZK/`.
- Outside the backend, the branch changes exactly three lines: one import in
  `Clean.lean`, two in `Clean/Test.lean`. `lakefile.lean` is unchanged from the
  pinned base. Verify with
  `git diff --stat 1e563b9c HEAD -- . ':!Clean/Backend' ':!doc/llzk' ':!scripts/llzk'`.
- No `sorry`, `partial`, `unsafe`, `panic!`, `.get!` or `[]!` anywhere in
  `Clean/Backend/`.
- 10 `#guard_msgs` goldens and 3 `#guard`s.
- 14 decisions, D001–D014.
