# Clean → LLZK current state

Updated: 2026-08-04  
Active milestone: **Stage 1 finished and reviewed; `GAPS.md` §3, §4 and §6
closed** — all gates G0–G12 green against the pinned tools, and green in CI  
Last accepted session: A4 — G9 reads types; and B, which found that CI had been
green on this branch for two days while three sessions said it had never run  
Integration branch: `clean-to-llzk/integration`  
Integration commit: `doc/llzk/evidence/A4/gates.txt`  
Pinned Clean base: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`

## Accepted pins

- Clean: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`
- LLZK source: `5db6f8f9baaa40787a1a40625796497445f2da36`
- LLZK tools: `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0`
- project-llzk VeIR: `eae1c27e7842c0503233ec99155c39791bd5f502`
- upstream VeIR: `a4e6194d5810a02d74f0094ff6014cda6db6d617`

See `PINS.md` for how to obtain the tools, including the cache-key requirement.

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

# 3. The pinned LLZK tools. This store path is one machine's; PINS.md has the
#    `nix build` that produces it, including the --max-jobs 0 discipline and the
#    substituter cache key. Get them from there before pasting this.
export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen

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
    the table certificates to all seven public entry points, which no longer
    accept a plain `Config`, so `GAPS.md` §1's first half — the *erasure* — is
    closed. Its second half is not, and is upstream.
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
  - `Gadgets.Addition8FullCarry` compiles to LLZK, `llzk-opt` accepts,
    round-trips and product-forms it, both witgen backends reproduce Clean's
    witness on every recorded input, and its emitted `@constrain` is Clean's own
    constraint system.
- In progress: none.
- Blocked: none.

## Last green gates

Evidence under `doc/llzk/evidence/`.

| Gate | Result |
|---|---|
| G0 state and pins | PASS — and since R6 it also fails on any change to Clean's core outside `Clean/Backend/LLZK/`, `Clean.lean` and `Clean/Test.lean` |
| G1 lint + `lake build --wfail Clean` + `lake build CleanTests` | PASS |
| G2 goldens: renderer (2) and six full emitted modules | PASS |
| G3 `llzk-opt` parse and verify | PASS — 12 modules + 2 fixtures |
| G4 `llzk-opt --verify-roundtrip` | PASS — 12 modules + 2 fixtures |
| G5 `llzk-witgen` interpreter | PASS — 33 vectors |
| G6 `llzk-witgen` execution engine | PASS — 33 vectors |
| G7 both backends vs Clean's own interpreter | PASS — carried by `--check-output` |
| G8 fail closed | PASS — 25 negative fixtures, plus tool-version rejection. Not "one per rejection path": R5 found three reachable paths with none, including the field-registry branch that was R4b-1's own repair. Those three now have fixtures; the claim is not reinstated as a general one |
| G9 the emitted `@constrain` **and** `@compute` are the circuit's | PASS — both preconditions of emission, so every circuit (D018, D020) |
| G10a LLZK analysis pipeline admits the module | PASS — all 14 |
| G11 the harness's own error paths | PASS — 42 exercised, including the worktree lock's opaque-owner branches, which R6 found were the ones that mattered and the ones nothing covered |
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

The largest, in order: lookup table rows are asserted by the caller and not
checked (D012 — and the `ConstraintSet.globals` conjunct that claimed to close
this is a tautology; S24 closed the *erasure* half of this, so the certificate
now reaches the compiler, but not the tie to the circuit's own table);
`Module.render` is outside every theorem, uncovered for `@constrain` — R6
replaced that entry's counterexample with two it verified against the pinned
tools, and narrowed the hazard to the three `Stmt` forms that appear only in
`@constrain`; there is no proof from the emitted constraints to a gadget's
`Spec`; `FieldExpr.lower_spec` is satisfied by five grossly wrong
lowerings and does not compose; and G9 compares no types. (§4 — the lookup half
having no semantic theorem — was on this list until A1 closed it.)

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
evidence: 30 vectors across two independent LLZK backends.

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
the tree carries a `sorry`.

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

## Roadmap after R6

Stage 1 is finished, reproduced, and reviewed twice by sessions that did not
write it. What remains sorts into five tracks. Nothing below is *in progress*;
these are the choices.

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
   plus three of Clean's own steps. Soundness direction only; D017 and §2 still
   stand between it and the text.
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
5. **§2 — the renderer.** R6 narrowed it: `readMember`, `constrainEq` and
   `constrainIn` are the three `Stmt` forms emitted only into `@constrain`, so
   they are the only ones no gate covers, and both verified mutations are in
   them. A parser back to `Module` over just those three, with a round-trip
   theorem, would close it — with the usual question of what checks the parser.
6. **§5 / D021 — the preservation theorem.** Turning D018's translation
   validation into a verified translator. R5a-4's three obstructions say the
   *reader* has to be restated before `lower_spec` can be lifted through the
   assembly loops. Largest item in this track and the one with the least leverage
   per hour, because `agree` already refuses a wrong module.
7. **§8 — the copy-canonicalisation premise**, currently three lines checked by
   inspection under two theorems that are proved. Small.

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

- **Subcircuits as named components** alongside `@Main`. This is the shape D015
  was chosen to be compatible with, and the reason the root name is a constant.
- **Multi-column tables** (D013): needs `array.new` and a multi-dimensional
  `constrain.in` in the emitter IR.
- **The rest of the witness IR**: `inv` → `felt.inv`, `ite` → `scf.if`,
  `listGet` → the array dialect, `let`-steps, `mapRange` → `scf.for`.
- **General natural arithmetic** (D011's deferred "general treatment"): `NExpr.val`
  → `cast.toindex`, arithmetic on `index`, `FExpr.ofNat` → `cast.tofelt`. Needs an
  index bounds policy and LLZK interpreter support that do not exist yet, which is
  why it is last and why D011 refuses everything but the two matched shapes.

### D. The AIR layer — an unfaced design decision

Clean's `Clean/Table/*` is genuine AIR: a trace of rows with
`EveryRow`/`EveryRowExceptLast`/`Boundary` transition constraints. **LLZK has no
analogue**, and Stage 1 and Stage 2 both sidestep it by compiling a single
flattened circuit. Prior art to copy rather than invent: the
`airbender-llzk-frontend` tree lowers AIR traces and lookups to LLZK. This is the
largest unscoped question in the project and it is not on any track above.

### E. VeIR — parallel, non-blocking

D003 holds: VeIR consumes the frozen `.llzk` fixture corpus rather than being a
dependency. `/home/alh/LLZK/clean-to-veir-readiness.md` has workstreams W0–W8 and
milestones VM1–VM4; `GAPS.md` §7 (D017 has no formal basis) is the gap only VeIR
can close, because closing it means formalising LLZK.

### Recommended order

**A1, A2, A4 and B are done — §3, §4 and §6 are closed and CI is green on a
runner.** Next: **A5, the renderer.** It is now the largest thing standing between
`spec_of_compile` and the emitted *text*, which is exactly what A2 makes it worth
doing, and R6 narrowed it to the three `Stmt` forms that appear only in
`@constrain`. After that A6 (the preservation theorem, D021) and A7 (the
copy-canonicalisation premise). A3 is more important than any of them but is a
Clean-core session, so it should be *scheduled* rather than slipped into a
backend increment — and G0 now enforces that.

One process item, from B: **check the world, not the document.** Track B was on
this list at all because three sessions in a row read a paragraph saying CI had
never run, and none of them ran `gh run list`. Any claim here about GitHub, the
LLZK toolchain, or anything else outside the worktree should be re-checked
against the thing itself before it is planned around.
