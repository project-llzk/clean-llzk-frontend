# Clean → LLZK current state

Updated: 2026-08-21

Active milestone: **public-ready Clean to LLZK release candidate** — make the
repository suitable for an organization-owned home under `project-llzk`, with a
clear public reading path, current upstream base, impactful library examples,
and a frozen adversarially reviewed assurance story. Acceptance criteria and the
critical path are in `PUBLIC-READINESS.md`. Stage 1 remains finished, reviewed
three times, and reproduced by R7; all gates were green against the pinned tools
and in CI, and the pipeline milestone (a Clean circuit compiled, validated, and
its emitted constraints proved to imply the gadget's `Spec`) stands.

Last accepted session: R7 — a five-surface adversarial review of the finished
Stage 1 *and of the plan*. The formal chain held; the coverage headline
(R7-05), two of the three bootstrapped session packets (R7-08, R7-09), and G0's
blindness to the working tree (R7-01) did not. All findings repaired in the
same session; the coverage sweep is now a checked test
(`Test/Coverage.lean`), `CertifiedTable` carries a name tie, and S28
(multi-column tables) joined the critical path  
Latest completed assurance session: **A7** — copy canonicalisation is now an
explicit `CopyCanon.run` used by `WitnessSet.ofSource`.
`CopyCanon.step_preserves` proves the single-cell update and `run_preserves`
proves the whole-list invariant: the representative map preserves the value of
every circuit variable. The existing copy-chain and non-copy red controls remain
green; theorem evidence is in `evidence/A7/`. This feature branch has not been
integrated or pushed. Full G0-G12 passed on clean commit `a32593bf`: 12 modules,
33 vectors through both witness backends, 2 renderer fixtures, G10a 14/14, and
G10b 10 lowered / 4 declared out of scope.

Latest completed presentation increment: **checked public showcase** —
`EXAMPLES.md` is generated from `Corpus.corpus`; unknown or failed entries,
empty vector sets, and invalid agreement states refuse generation. G1 compares
the generated and checked-in page byte-for-byte, while `Test/Showcase.lean` pins
the corpus ordering, denominator, vector total, source-backed count, and purpose
coverage. Full G0-G12 passed on clean commit `b16bb83e`; evidence is in
`evidence/P0/showcase.txt`.

Next session: **S25** — `sessions/S25-align-upstream.md`, **as corrected by R7**
(read its Deliverable 2a first). Bootstrapped, not started; changing the Clean
pin remains an explicit decision boundary

Integration branch: `clean-to-llzk/integration`

Active working branch: `clean-to-llzk/publication-hygiene` (security reporting,
pull-request evidence, and reviewed organization settings on top of the checked
showcase; no pin, capability, or external-state change)

Integration commit: `doc/llzk/evidence/R7/gates.txt`

Pinned Clean base: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`

Publication state, verified 2026-08-21: local `clean-to-llzk/integration` is at
`97390fac`, seven commits ahead of the fork remote. The open fork PR #1 is still
at `7ff51310`; all four CI jobs are green there, but A4 and R7 have therefore
been reproduced only by their committed local evidence, not by CI at their own
commits. A public release candidate must put the branch, evidence, and CI on the
same frozen commit. No push is authorized by this status update.

Dependency state, also verified 2026-08-21: Clean upstream remains exactly
`0e53b9f2`, S25's reviewed target. LLZK `main` is now `25fb3740`, 25 commits
ahead of the accepted `5db6f8f9` tool pin. The delta touches LLZK core
transforms, analysis, and `llzk-witgen`, not only unrelated backends. The
3.0.0 pin remains accepted and reproducible; public readiness adds an isolated
L0 review after S25 to decide whether to retain it or advance it and rerun the
full compatibility matrix.

## Accepted pins

- Clean: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`
- LLZK source: `5db6f8f9baaa40787a1a40625796497445f2da36`
- LLZK tools: the Nix output of the pinned LLZK source; reports version 3.0.0
- project-llzk VeIR: `eae1c27e7842c0503233ec99155c39791bd5f502`
- upstream VeIR: `a4e6194d5810a02d74f0094ff6014cda6db6d617`

See `PINS.md` for how to obtain the tools, including the cache-key requirement.

**The Clean pin is stale, deliberately and with a plan.** Upstream `main` is
`0e53b9f2` on Lean **4.32.2**, 70 commits ahead, merged 2026-08-04. It **deletes
`Witgen.NExpr`** — the sort D011's whole argument is about — in favour of a
bounded `U64Expr`, and makes bit decomposition a constructor (`VExpr.bitsOf`).
D025 records why that means aligning comes *before* any new capability, and
`sessions/S25-align-upstream.md` is the packet. Do not add witness-IR capability
at this pin; it targets types that no longer exist upstream.

## Reproduce everything

From a fresh checkout, in this order — every line of it is load-bearing, and S24
established that by running it (`evidence/S24/clean-checkout.md`):

```bash
# 0. If the tree carries someone else's lock and you know that session is done:
#    `reclaim` alone only works for a numeric owner this machine can prove dead.
#    An LLZK_SESSION owner is opaque, so you have to name it (D024).
#      bash scripts/llzk/worktree-lock.sh status
#      bash scripts/llzk/worktree-lock.sh reclaim "what you are doing" --from '<id>'

# 1. G0 checks provenance against `upstream`, which a fresh clone does not have.
git remote add upstream git@github.com:Verified-zkEVM/clean.git

# 2. Fetch mathlib's build cache. Skipping this does not fail — it builds mathlib
#    from source, 1837 targets, and that dominates everything else here.
lake exe cache get

# 3. Build/substitute the pinned LLZK tools. The command prints a machine-local
#    Nix store path; PINS.md records the required cache key.
nix build --no-link --max-jobs 0 --print-out-paths \
  github:project-llzk/llzk-lib/5db6f8f9baaa40787a1a40625796497445f2da36#llzk
export LLZK_OPT=/the/printed/store/path/bin/llzk-opt
export LLZK_WITGEN=/the/printed/store/path/bin/llzk-witgen

# 4. The gates.
bash scripts/llzk/worktree-lock.sh claim "what you are doing"
bash scripts/llzk/e2e.sh
```

`e2e.sh` refuses to run without the worktree lock (S24): it rebuilds
`.lake/llzk` from scratch, and evidence is only attributable to a commit if one
session owned the tree while it ran. **From an agent harness, prefix both
commands with `LLZK_SESSION=<label>`** — each command there is its own POSIX
session, so the default identity does not survive from the claim to the run.
`doc/llzk/CONCURRENCY.md` has the why.

Expected: `PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12` — 12 circuits, 33
input vectors, both witgen backends, 2 renderer fixtures, 10 modules lowered to
SMT and 4 out of scope for a declared reason.

CI is *configured* to run G0, G11 and G12 on every pull request, and G1–G10 in
the `llzk-e2e` job, which builds the pinned LLZK from the same flake reference
`PINS.md` records. Until R5 none of the LLZK gates were in CI at all.

**It has run, and it was green.** This paragraph said "None of it has ever run"
from `262c9684` until 2026-08-04, and it was false for two of those days.

The facts, from `gh run list --branch clean-to-llzk/integration`:

- `alexanderlhicks/clean` **PR #1** was opened 2026-08-02T03:18:55Z — three
  minutes after S24 took the worktree lock.
- CI ran on it at `4e15d3ad` three seconds later and **all four jobs passed**:
  `build`, `llzk-harness`, `llzk-e2e` and `plonky3-backend`.
- So `llzk-e2e` works on a GitHub runner, including
  `nix build …#llzk` — the risk this document and R6 both flagged as the likely
  first failure did not materialise.

**How this survived.** S24's handoff recorded "S24 asked and got no answer, so
nothing was pushed and the jobs stay marked unrun". The push and the PR happened
anyway, minutes later, and no session updated the paragraph. R6 then *read* it,
repeated it in its roadmap as "CI has never run / untested code", and did not
check — while auditing this project for exactly that. A1 and A2 carried it
forward again. One `gh run list` would have falsified it at any point.

It is the same lesson as R6-2 and R6-3, in the place hardest to see: **a claim
about the world outside the repository has to be checked against the world, and
the control plane is not evidence about itself.**

**What it costs, which nobody had measured either.** `llzk-e2e` took **4h23m** on
2026-08-02 (03:22:08 → 07:45:45) and the 2026-08-04 run is on the same step at
the same pace. Essentially all of it is step 6, `nix build …#llzk`, building LLZK
from source because the runner has no substituter for it; `llzk-harness` by
contrast is 11 seconds.

That matters for two reasons. GitHub's per-job limit is 6 hours, so the job
currently finishes with about 25% of head-room and a slower runner or a heavier
LLZK would turn a green gate into a timeout — a failure mode indistinguishable
from a real one. And every push to the PR spends four and a half hours of runner
time, which makes `llzk-e2e` something to trigger deliberately rather than a
check you get on each commit.

The fix is a binary cache for the pinned LLZK — `PINS.md` already records a
substituter and cache key for the local build; pointing `cachix/install-nix-action`
at the same one would cut step 6 to a download. Not done here: it needs a cache
the fork can read, which is a decision about infrastructure rather than a change
to this repository.

What is still true: every gate in the table below is green on one machine *and*
on a runner, but only G0–G12 are gated in CI; §11 still reserves publishing for
an explicit decision, which was given.

## State

- Completed:
  - S00 control plane; S03 emitter IR and renderer; S04 analysis, layout and the
    assertion-only slice; S05 the natural division/modulo shapes; S06 tables and
    lookups; S07 the emitter command and harness; S01 tooling; S02 validation.
  - **R2**, the Stage-1 adversarial acceptance review: returned for repair, 15
    findings. `review/R2-findings.md`.
  - **S08–S15**, the repair: every finding discharged, with the resolution and
    its evidence in `review/R2-resolution.md`.
  - **R3**, a review of that repair: three defects in its own new code, fixed.
    `review/R3-findings.md`.
  - **S16–S18**, closing the three gaps the repair had documented rather than
    fixed: D012's lookup rows (proved), G9's scope (now every circuit, not the
    corpus), and R2-05's field law (now a required class).
  - **S19**, the witness side of G9, and the corpus outside
    `Addition8FullCarry`'s `Assumptions`.
  - **R4**, two *independent* adversarial reviews — the first review of this work
    by anything other than the session that wrote it. Nine findings, five
    breaking a written claim, two of them severe. All fixed and every
    counterexample re-run. `review/R4-findings.md`.
  - **R5**, five independent adversarial reviews run against a frozen tree —
    theorem statements, documentation versus elaborated reality, a red team,
    gate falsification, and the trusted base. One soundness break (a `Config`
    could weaken the emitted constraint system with every gate green), one
    completeness break (a proved `FormalCircuit` refused and told to file a
    backend bug), and nine claims stated more strongly than the code supported.
    `review/R5-findings.md`; the boundaries it established are `GAPS.md`.
  - **S21–S22**, the repair: the doors confined (G12), the harness's own error
    paths gated (G11), D011's side conditions moved below every door, and the
    LLZK gates put into CI for the first time.
  - **S24**, finishing Stage 1. The worktree lock became a gate — and wiring it
    in exposed that it did not protect agent sessions at all, because the POSIX
    session id it defaulted to is the *command* under a harness, so a claim was
    stale by the next command and `claim` took a stale lock silently. `reclaim`
    is now separate, `LLZK_SESSION` is the identity, and CI claims rather than
    being exempted (D023). Then S23 was executed: `CertifiedConfig F` carries
    the table certificates to the five public entry points (R7-15 corrected
    "seven", which had counted two theorems), which no longer accept a plain
    `Config`, so `GAPS.md` §1's first half — the *erasure* — is closed. Its
    second half is not, and is upstream.
  - **R6**, an adversarial review of the finished Stage 1 and its repair. The
    gates reproduced on the reviewed commit before anything changed; four claims
    were attacked specifically and held, above all D019's survival through
    elaboration. Six findings, all fixed: `reclaim` was unreachable for every
    identity D023 introduced it for (D024); `GAPS.md` item 2's counterexample was
    one the toolchain *does* catch, and the correct one is now recorded and
    verified; Clean-core byte-identity was an invariant three documents argue
    from and no gate checked; `copyCell` — the one shape this project has
    demonstrably misread — was in neither the goldens nor the corpus and had
    reached no LLZK tool; `ROADMAP.md` overstated four closed gaps; two stale
    pointers. `review/R6-findings.md`.
  - **A1**, closing `GAPS.md` §4 — the first item of the roadmap below.
    `Lookups.lean` gives the lookup half of `ConstraintsHoldFlat` the semantic
    theorem the assertion half had had since S15, and `Test/Lookups.lean`
    instantiates it, and `byteTable_lookup_iff`, at `Addition8FullCarry`. What
    made it possible was making "the compiler ran a check" into a proposition:
    `registryOk_of_recognize` and `size_eq_of_recognize` (D010 as a theorem) turn
    a successful `recognize` into the canonicity bound `certified_membership`
    needs, so nothing is assumed at the call site. Two behaviour-preserving
    refactors of `recognize` were needed first — an overlapping `match` that
    generated no equation lemmas, and a `for` loop that hid the field check
    inside `forIn`. No new axioms.
  - **A2**, closing `GAPS.md` §3 — the statement R5e said a user most likely
    assumes the project has. `Soundness.spec_of_compile`: if the emitted module's
    `@constrain` is satisfied at an assignment and the gadget's `Assumptions`
    hold there, the gadget's own `Spec` holds. Three of its four links are
    Clean's own; the one that did not exist was A1's lookup theorem, and
    `Operations.FullGuarantees` turned out to be *free* because it quantifies
    over channel interactions, which `Analyze` refuses by name. Instantiated at
    `Addition8FullCarry`, with everything about the circuit discharged by proof.
    G12 also became a code-reading check rather than a grep over comments, after
    three files in one session had been added to its allowlist for prose alone —
    the allowlist shrank instead.
  - **A4**, closing `GAPS.md` §6. Both G9 readers now take the expected `Ty` and
    check it at every operand, parameter, `struct.member` and `global.def`;
    array types are checked exactly against the global being read, length
    included. `Test/Constraints.lean` pins R5e's own counterexample — reading a
    babybear module as `bn254` — going red on both readers. Turning the check on
    immediately found a defect in the tests it was meant to protect: a `#guard`
    compared every corpus module against a hard-coded babybear, wrong for five of
    the six `Square_*` entries, so `Corpus.Entry` now carries its `FieldSpec`.
  - **B**, publishing — and the finding that it had already happened. See
    "Reproduce everything" above: PR #1 has been open since 2026-08-02 with CI
    green on all four jobs, while this document said none of it had ever run and
    R6 repeated that in its roadmap without checking.
  - **R7**, five independent adversarial reviews of the finished Stage 1, the
    closed gaps, the gates, and — for the first time — the *plan*. What held:
    the gates (reproduced before anything changed), the soundness chain link by
    link, axiom hygiene exactly as documented, the fatBytes attack blocked by
    `resolve`, and the R2-06/R4b-2 vacuity class still closed. What did not:
    the coverage headline — "bitwise blocked by exactly two constructors" was
    false, 80–89% of its own diagnostics being multi-column-lookup refusals
    (R7-05), so **D013's retirement is now on the critical path (S28)**; S25's
    "translate exactly, re-prove `eval_ofWitgen`" is unsatisfiable because
    upstream `U64Expr.val` truncates (R7-08); S27's premises were false three
    ways — GF(2) not bn254, no bitwise ops, real blocker `letF` (R7-09); G0
    never looked at the working tree it certified (R7-01, fixed + G11 case);
    three refusal paths had no fixture (fixed, 29 now); `CertifiedTable` had no
    name tie, leaving `spec_of_compile`'s lookup hypothesis incomparable with
    module satisfaction under swapped names (R7-12, fixed with
    `name_certifies`); the coverage sweep was unreproducible (fixed —
    `Test/Coverage.lean` pins every verdict and its decomposition); and eight
    document-drift items (R7-13…17). `review/R7-findings.md`,
    `evidence/R7/`.
  - `Gadgets.Addition8FullCarry` compiles to LLZK, `llzk-opt` accepts,
    round-trips and product-forms it, both witgen backends reproduce Clean's
    witness on every recorded input, and its emitted `@constrain` is Clean's own
    constraint system.
  - **A5**, closing `GAPS.md` section 2. `Module.render` reads the three
    constraint-only statement forms back from text, including independently
    reconstructed types and the function boundary, before releasing an
    artifact. `Module.render_constraintSurface` states the generic round trip;
    five mutations make it red. G0-G12 passed on clean commit `28132f64`.
- In progress: none.
- Decision pending: authorize S25's move of the accepted Clean base from
  `1e563b9c` / Lean 4.30.0 to `0e53b9f2` / Lean 4.32.2. This is not a technical
  blocker; the project control plane reserves pin changes for an explicit
  decision.
- Blocked: none.

## Last green gates

Evidence under `doc/llzk/evidence/`.

Latest complete run: public showcase, clean commit
`b16bb83ead9d9fc8dabfcda4a2d9da2db2e765a5`; see
`evidence/P0/showcase.txt`. The A7 theorem probe remains part of the same tree
and reports only `propext` and `Quot.sound` for both copy-canonicalisation
invariants.

| Gate | Result |
|---|---|
| G0 state and pins | PASS — and since R6 it also fails on any change to Clean's core outside `Clean/Backend/LLZK/`, `Clean.lean` and `Clean/Test.lean` |
| G1 lint + `lake build --wfail Clean` + `lake build CleanTests` | PASS |
| G2 renderer: goldens plus checked constraint-surface round trip | PASS — 2 renderer fixtures, 12 corpus modules, 5 red mutations |
| G3 `llzk-opt` parse and verify | PASS — 12 modules + 2 fixtures |
| G4 `llzk-opt --verify-roundtrip` | PASS — 12 modules + 2 fixtures |
| G5 `llzk-witgen` interpreter | PASS — 33 vectors |
| G6 `llzk-witgen` execution engine | PASS — 33 vectors |
| G7 both backends vs Clean's own interpreter | PASS — carried by `--check-output` |
| G8 fail closed | PASS — 29 negative fixtures, plus tool-version rejection. Not "one per rejection path": R5 found three reachable paths with none, and R7 found three more (R7-04); each round's were added and the general claim is not reinstated |
| G9 the emitted `@constrain` **and** `@compute` are the circuit's | PASS — both preconditions of emission, so every circuit (D018, D020) |
| G10a LLZK analysis pipeline admits the module | PASS — all 14 |
| G11 the harness's own error paths | PASS — 43 exercised, including the worktree lock's opaque-owner branches, which R6 found were the ones that mattered and the ones nothing covered, and since R7 the uncommitted-core-edit branch of G0 (R7-01) |
| G12 reads code, not comments | PASS — A2; a docstring naming an entry point is no longer a call site, so the allowlist shrank rather than grew |
| G9 compares types | PASS — A4; both readers check every `Ty` against the configured field, and array types exactly against the global read. Was `GAPS.md` §6 |
| G12 every gate-skipping entry point is confined | PASS |
| G10b SMT lowering | PASS — 10 lowered, 4 out of scope for a declared reason |

Every gate is checked to be falsifiable, and the checks are part of the gate
rather than notes about it:

- the witness gates, by `require_llzk_witgen_discriminates`, which runs
  `llzk-witgen` against a perturbed witness before the loop and aborts if it
  passes (R2-06);
- G3, G4 and G10, by `require_llzk_opt_discriminates`, which requires `llzk-opt`
  to reject a non-MLIR file *and* a well-formed MLIR module that is invalid LLZK
  — a shim answering only `--version` used to make all three vacuous while the
  harness printed PASS (R4b-2), and the non-MLIR probe alone was satisfied by any
  generic MLIR parser, which LLZK 3.0.0 itself demonstrates by accepting a module
  containing no LLZK at all (R5d);
- G9, by `Test/Constraints.lean`, which perturbs the Clean side six ways and
  pins that the comparison goes red for each;
- G10a, by the control in `evidence/S08-S15/controls.txt`: a module whose root is
  not `@Main` fails it;
- G10b, by a floor on *refusals*: the corpus contains modules the SMT pass cannot
  lower, so a run in which it refused nothing means it is not running;
- and the checks themselves, by G11 — `scripts/llzk/test-scripts.sh`, which
  drives each one against a shim built to defeat it. Until R5 nothing exercised
  any harness failure branch, which is how a repair to `check-pins.sh` shipped
  dying with `llzk_fail: command not found` instead of the message it was written
  to print, and survived two reviews.

## What is still not established

**`doc/llzk/GAPS.md` is the register.** It exists because this section used to be
the register and was not one: it listed "one boundary and one improvement", and
R5's five reviewers found nine claims across the codebase that were stated more
strongly than the code supported. Two of them were consequences of paragraphs
that stood right here. The list below is the summary; `GAPS.md` is the thing to
read, and the docstrings it points at now agree with it.

The largest still open, in order (R7-14 — an earlier version of this paragraph
kept listing §3 and §6 after other sections of this same file recorded them
closed): lookup table rows are asserted by the caller and not checked (D012 —
and the `ConstraintSet.globals` conjunct that claimed to close this is a
tautology; S24 closed the *erasure* half, so the certificate reaches the
compiler, and R7 tied it to the table's *name*, but not to the circuit's own
table); and `FieldExpr.lower_spec` is satisfied by five grossly wrong lowerings
and does not compose. (§4 was on this list until A1 closed it; §3 until A2 —
`spec_of_compile`, with R7-12's correction of what its lookup hypothesis says;
§6 until A4; §2 until A5's checked textual constraint-surface round trip; and
§8's copy-canonicalisation premise until A7.)

The lookup side, which R4a-6 found had no semantic theorem, has one:
`Lookups.ofSource_lookups_iff`, the counterpart of `ofSource_eqs_iff`. This
paragraph used to say its canonicity hypothesis was "discharged from the
compiler's own registry check", and R5a-7 corrected that to "nothing instantiates
the theorem, so nothing discharges its hypothesis". Since A1 the original
sentence is true and is a theorem: `canonical_of_recognize` derives the bound
from `registryOk_of_recognize` and `size_eq_of_recognize`, and
`Test/Lookups.lean` instantiates both it and `byteTable_lookup_iff` at
`Addition8FullCarry`. One hypothesis is left and is named — that the compiler
accepted the circuit, which is a `#guard` rather than a `rfl`.

**D017 — the reading of LLZK — cannot be closed from this repository.**
`llzk-witgen`'s help text says it outright: *"llzk-witgen v1 ignores constrain()
and traps on bool.assert."* There is no executor for `@constrain` in the pinned
toolchain, and no formal LLZK semantics in Lean, so the assumption that
`constrain.eq` is equality and `constrain.in` is membership has no empirical
check and cannot acquire one here. Closing it means formalising LLZK, which is
VeIR's project (D003). The `@compute` half of the same reading *does* have
evidence: 33 vectors across two independent LLZK backends (27 with a Clean
circuit behind them; R7-15 unified the stale counts).

**S20 — the preservation theorem — exists, and is much smaller than this section
used to claim.** Every module `compile` returns has been compared against its
circuit on both sides, so a lowering bug yields a *refusal*, never a wrong
module; that part holds.

Two corrections R5 forced. The refusal is no longer "merely never-observed" — R5c
observed one, on a proved `FormalCircuit` whose emitted module was correct, and
the reader was at fault. And `FieldExpr.lower_spec`, the theorem S20 produced,
turns out to be satisfied by a lowering that throws on every expression, one that
emits everything in the wrong field, and one that appends a bogus
`constrain.eq %v, 0` to every subexpression. Lifting it through the assembly
loops — the plan for S21 — would have been lifting almost nothing; R5a-4 gives
three obstructions. `GAPS.md` item 5.

It was attempted, and the attempt found that the obstacle is not the one D018
implied. It is not the state monad: it is that `Value.mk`, `Builder.fresh`,
`Builder.emit` and `BuilderState`'s fields are all private — D005's first
invariant, which R4b-3 had just tightened — while `FieldExpr` lives in a module
that imports them, so the proof has nowhere to live. **D021** records the three
ways out and recommends one (make the emitters pure functions and keep the monad
as a wrapper). The attempt was reverted rather than left half-built; nothing in
the *backend* carries a `sorry` — and its axiom closure is clean, checked by
`#print axioms` in `evidence/R7/probes.txt`. (Not "nothing in the tree": pinned
Clean core carries one at `Clean/Circomlib/Poseidon.lean:22`, outside the
backend's closure, plus deliberate ones in `Clean/Utils/Test/` — R7-16.)

Two smaller facts, stated so they are not mistaken for gaps: the whole-vector
witness statement rests on the block-prefix discipline `Analyze` enforces rather
than proves; and no solver has run on an emitted module, because `llzk-smt-check`
needs SMT-LIB that no pass in the pinned `llzk-opt` produces.

## Known constraints

- The frontend is a pure Lean backend in Clean which emits textual LLZK.
- VeIR is an independent consumer/proof track, not an initial dependency.
- Stage 1 accepts only the fail-closed subset in `ROADMAP.md`.
- The root component is always `@Main` (D015); the circuit's name is the
  artifact's file name.
- Heavy Nix and Lean builds must not run concurrently on this machine; doing so
  produced a spurious Lean target failure during S00, and again during S24 — that
  time with the mechanism identified. `Clean/Gadgets/ByteDecomposition/`
  `Theorems.lean:62` is a `bv_decide`, so it is subject to a **solver time
  limit**: under load it fails with "The SAT solver timed out while solving the
  problem" and G1 goes red on a tree that is correct. It succeeded on retry with
  nothing changed. `evidence/S24/clean-checkout.md` finding 4.

## Next session

**Claim the worktree first** — `bash scripts/llzk/worktree-lock.sh claim "..."`,
and set `LLZK_SESSION` if you are an agent session, or the claim will not survive
your next command. `e2e.sh` refuses without it. If the tree already carries a
finished session's lock, `status` will say whether `reclaim` needs `--from`
(D024). Three sessions collided on 2026-08-01; `CONCURRENCY.md` records the cost.

## The next sessions, as R7 corrected them

Bootstrapped 2026-08-04; **R7 falsified parts of all three packets against the
primary sources before execution** (R7-08…11), and the corrections are written
into the packets themselves. Read them in order.

| packet | does | R7 correction |
|---|---|---|
| `sessions/S25-align-upstream.md` | bump to upstream `0e53b9f2` / Lean 4.32.2 | constructor inventory fixed (three errors); **Deliverable 2a added**: upstream `U64Expr.val` truncates, so `eval_ofWitgen` cannot be re-proved as stated — restating it costs bn254/grumpkin div/mod coverage and must be recorded as a decision (D026), which no gate can see |
| `sessions/S26-witness-u64.md` | lower `U64Expr` structurally; `bitsOf`, `land`/`lor`/`lxor`, `ite` | unlocks ~5 lookup-free gadgets, **not** the bitwise half (R7-05); the width decision must also cover the `val` bridge on *large* fields |
| `sessions/S28-multicolumn-tables.md` | **new** — retire D013: `array.new`, multi-dim `constrain.in`, certification at 65536×3 | this, with S26, is what actually unlocks Xor32/And8/Keccak/BLAKE3; outline now, expand after S26 |
| `sessions/S27-fork-gadgets.md` | port `~/zkgolf/submission_gf2` onto fork `main` | **returned for re-scoping** (R7-09): the submission is GF(2) — not an LLZK field — has zero bitwise ops, and its real blocker is `letF`. The port survives as Clean-side library work; its backend payoff needs a decision first |

S25 keeps the accepted subset exactly the size it is now, so its gates say one
thing only: the bump did or did not break the backend — except D026, which only
the theorem statement and the decision register can express (R7-08's point: the
realistic bump failure is green gates over a silently weakened theorem). S26 is
where capability grows; S28 is where the *library* does.

## Roadmap after R7

Stage 1 is finished, reproduced, and reviewed three times by sessions that did
not write it. What remains sorts into five tracks. Nothing below is *in
progress*; these are the choices.

**The two milestones, stated in the grant's terms.** Milestone 1 — one Clean
circuit compiled through the whole LLZK pipeline, validated end to end — is
**done and revalidated by R7**: gates green on this machine and in CI, the
formal chain attacked and held. Milestone 2 — the *library* of Clean circuits —
is what the corrected plan below is for, and its honest denominators are in
`ROADMAP.md`'s coverage section: ~7 of ~128 tops measured-compiling today,
S26+S28 unlock the ~29-gadget bitwise family, the witness-IR loop increment
(`letF`/`mapRange`/`shr`) unlocks SHA256 and most Circomlib bit gadgets, `inv`+
`ite` unlock the comparator family, and a `Compilable` story for
`GeneralFormalCircuit`/`FormalAssertion` (37 tops have no entry point today)
plus the AIR layer (track D) are the two design decisions standing between
this backend and the rest.

### A. Close the assurance gaps in this repo

`GAPS.md` is the register; this is the order to take them in, which is not the
order they are written in there.

1. **§4 — done (A1).** `Lookups.lean` and `Test/Lookups.lean`: the lookup half of
   `ConstraintsHoldFlat` has the semantic theorem it lacked, both it and
   `byteTable_lookup_iff` are instantiated at `Addition8FullCarry`, and the
   canonicity hypothesis is discharged from the compiler's own registry and field
   checks rather than assumed — `diagnose_of_mem_registry`,
   `registryOk_of_recognize`, `size_eq_of_recognize`. One hypothesis remains and
   is named: "the compiler accepted this circuit", a `#guard` rather than a `rfl`
   because `recognize` on a real gadget does not reduce in the kernel.
2. **§3 — done (A2).** `Soundness.lean` and `Test/Soundness.lean`:
   `spec_of_compile` is "the emitted module's constraints hold ⇒ the gadget's
   `Spec` holds", and `add8_spec_of_compile` is it for `Addition8FullCarry`.
   `Operations.FullGuarantees` turned out to be free — it quantifies over channel
   interactions, which `Analyze` refuses — so the chain is A1's lookup theorem
   plus three of Clean's own steps. Soundness direction only; A5 now bridges the
   protected surface to text, while D017's semantics assumption remains.
3. **§1's second half — tie a certificate to the circuit's own table.** The
   largest open *soundness* gap: the caller picks both sides of `Certifies`, so
   it can certify a table the circuit does not look into. Closing it needs the
   `Table` to survive into `Lookup` instead of being erased to a `RawTable`. That
   is a change to Clean's core, which since R6 is a **gate** — so it is a
   Clean-side session with its own review, reserved by ORCHESTRATION §11, not an
   increment here.
4. **§6 — done (A4).** Both readers take the expected `Ty` and check it at every
   operand, parameter, member and global; array types are checked exactly against
   the global being read. `Test/Constraints.lean` pins R5e's own counterexample
   going red. It shook out one real defect in the tests: a `#guard` checked every
   corpus module against a hard-coded babybear, which is wrong for five of the six
   `Square_*` entries — `Corpus.Entry` now carries its `FieldSpec`.
5. **§2 — done (A5).** The supported renderer parses `readMember`,
   `constrainEq` and `constrainIn` back from the concrete `@constrain` function,
   compares them with the typed module, and refuses mismatches before text is
   returned. The theorem and five red controls are in `Print.lean` and
   `Test/Print.lean`. D017 remains separate.
6. **§5 / D021 — the preservation theorem.** Turning D018's translation
   validation into a verified translator. R5a-4's three obstructions say the
   *reader* has to be restated before `lower_spec` can be lifted through the
   assembly loops. Largest item in this track and the one with the least leverage
   per hour, because `agree` already refuses a wrong module.
7. **§8 — done (A7).** `CopyCanon.step_preserves` proves that one
   canonicalisation step preserves the semantic representative invariant, and
   `run_preserves` lifts it across the whole witness-program list.
   `WitnessSet.ofSource` uses that `run` rather than a mutable update. Together
   with `WExpr.eval_rename` and `WExpr.eval_congr`, the copy-collapse argument no
   longer has an inspection-only premise. The theorems use only `propext` and
   `Quot.sound`; the probe is in `evidence/A7/`.

### B. CI — **done, and it was already done**

`alexanderlhicks/clean` PR #1, open since 2026-08-02, and CI green on it at
`4e15d3ad`: `build`, `llzk-harness`, `llzk-e2e`, `plonky3-backend`. The workflow
is not untested code and `nix build …#llzk` does work on a runner. See
"Reproduce everything" above for how this document managed to say otherwise for
two days, and what R6 should have done about it.

What remains is upkeep rather than a decision: keep the PR current, and treat a
red run as a gate like any other.

### C. Stage 2 — capability

In dependency order, each an increment of the shape D009 describes (one
`FieldExpr` constructor, one recognizer case, one `lower` case, one positive and
one negative fixture):

- **Bitwise operations first** — `land`/`lor`/`lxor`, then `ite` (`scf.if`) —
  **S26**. The seven arithmetic rows of `ROADMAP.md`'s coverage table already
  compile (`Addition32Full`, `Rotation64`, `Not64`, `ByteDecomposition`,
  subcircuits and lookups included). What this increment does *not* do is
  unlock the bitwise gadgets — R7-05 corrected the claim that it would.
- **Multi-column tables** (D013) — **S28**, immediately after, because it is
  the other half of the same unlock: every byte-oriented bitwise gadget looks
  up a 3-column `ByteXorTable`-family table. `array.new`, a multi-dimensional
  `constrain.in`, and table certification at 65536×3.
- **The rest of the witness IR**: `let`-steps and `mapRange` → `scf.for` (this
  is SHA256's real blocker, R7-07, and the zkGolf Add32 ports' too, R7-09),
  `inv` → `felt.inv` (with `ite`, the `IsZero`/comparator family), `listGet` →
  the array dialect.
- **A `Compilable` story beyond `FormalCircuit`** — `GeneralFormalCircuit`,
  `FormalAssertion` and `LookupCircuit` tops (28 in `Gadgets`+`Circomlib`)
  cannot reach `compile` at all today; R7-07 found the coverage table silently
  excluded them. Whether each gets an instance, an adapter, or a documented
  refusal is a design decision to record, not code to sneak in.
- **Subcircuits as named components** alongside `@Main`. This is the shape D015
  was chosen to be compatible with. A scaling concern rather than a capability
  one.
- **General natural arithmetic** (D011's deferred "general treatment", now over
  `U64Expr`): needs an index bounds policy and LLZK interpreter support that do
  not exist yet, which is why it is last.

### D. The AIR layer — an unfaced design decision

Clean's `Clean/Table/*` is genuine AIR: a trace of rows with
`EveryRow`/`EveryRowExceptLast`/`Boundary` transition constraints. **LLZK has no
analogue**, and Stage 1 and Stage 2 both sidestep it by compiling a single
flattened circuit. Prior art to copy rather than invent: the
`airbender-llzk-frontend` tree lowers AIR traces and lookups to LLZK. This is the
largest unscoped question in the project and it is not on any track above.

### E. VeIR — parallel, non-blocking

D003 holds: VeIR consumes the frozen `.llzk` fixture corpus rather than being a
dependency. Its separately tracked readiness plan has workstreams W0–W8 and
milestones VM1–VM4; `GAPS.md` §7 (D017 has no formal basis) is the gap only VeIR
can close, because closing it means formalising LLZK.

### Recommended order

**A1, A2, A4, A5, A7 and B are done; R7 revalidated everything through A4.** The
next thing is still **S25**, the upstream alignment — the pin is more than six
weeks old and 70 upstream commits behind, the
witness IR underneath us has been rebuilt (D025), and upstream has not moved
past `0e53b9f2` (checked 2026-08-21) — but execute it *as R7 corrected it*:
Deliverable 2a (the `val`-truncation decision, D026) is the part the gates
cannot see. Then **S26** (bitwise + `ite`, with the val bridge in its decision
entry), then **S28** (multi-column tables — new, and the actual library
unlock), then the witness-IR loop increment. S27 is returned for re-scoping and
should not be executed as written (R7-09).

The assurance track's A5 renderer and A7 copy-canonicalisation items are now
done: the on-disk constraint surface has the second line of defense R7-02 called
for, and the copy-collapse premise is proved rather than inspected. Its next
independent backend item is A6 (the preservation theorem, D021). A3 is more
important but is a Clean-core session, so it should be *scheduled* rather than
slipped into a backend increment — and G0 now enforces that, including against
uncommitted edits (R7-01).

One process item, from B: **check the world, not the document.** Track B was on
this list at all because three sessions in a row read a paragraph saying CI had
never run, and none of them ran `gh run list`. Any claim here about GitHub, the
LLZK toolchain, or anything else outside the worktree should be re-checked
against the thing itself before it is planned around.
