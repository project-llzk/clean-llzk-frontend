# Clean → LLZK current state

Updated: 2026-08-01  
Active milestone: **Stage 1 repaired and re-reviewed** — all gates G0–G12 green
against the pinned tools  
Last accepted session: R5 — five independent reviews, and their repairs  
Integration branch: `clean-to-llzk/integration`  
Integration commit: recorded in `review/R5-findings.md`  
Pinned Clean base: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`

## Accepted pins

- Clean: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`
- LLZK source: `5db6f8f9baaa40787a1a40625796497445f2da36`
- LLZK tools: `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0`
- project-llzk VeIR: `eae1c27e7842c0503233ec99155c39791bd5f502`
- upstream VeIR: `a4e6194d5810a02d74f0094ff6014cda6db6d617`

See `PINS.md` for how to obtain the tools, including the cache-key requirement.

## Reproduce everything

```bash
export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen
bash scripts/llzk/e2e.sh
```

Expected: `PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12` — 11 circuits, 30
input vectors, both witgen backends, 2 renderer fixtures, 9 modules lowered to
SMT and 4 out of scope for a declared reason.

CI runs G0, G11 and G12 on every pull request, and G1–G10 in the `llzk-e2e` job,
which builds the pinned LLZK from the same flake reference `PINS.md` records.
Until R5 none of the LLZK gates ran in CI at all.

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
| G0 state and pins | PASS |
| G1 lint + `lake build --wfail Clean` + `lake build CleanTests` | PASS |
| G2 goldens: renderer (2) and five full emitted modules | PASS |
| G3 `llzk-opt` parse and verify | PASS — 11 modules + 2 fixtures |
| G4 `llzk-opt --verify-roundtrip` | PASS — 11 modules + 2 fixtures |
| G5 `llzk-witgen` interpreter | PASS — 30 vectors |
| G6 `llzk-witgen` execution engine | PASS — 30 vectors |
| G7 both backends vs Clean's own interpreter | PASS — carried by `--check-output` |
| G8 fail closed | PASS — 24 negative fixtures, plus tool-version rejection. Not "one per rejection path": R5 found three reachable paths with none, including the field-registry branch that was R4b-1's own repair. Those three now have fixtures; the claim is not reinstated as a general one |
| G9 the emitted `@constrain` **and** `@compute` are the circuit's | PASS — both preconditions of emission, so every circuit (D018, D020) |
| G10a LLZK analysis pipeline admits the module | PASS — all 13 |
| G11 the harness's own error paths | PASS — 20 exercised |
| G12 every gate-skipping entry point is confined | PASS |
| G10b SMT lowering | PASS — 9 lowered, 4 out of scope for a declared reason |

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
this is a tautology); `Module.render` is outside every theorem, uncovered for
`@constrain`; there is no proof from the emitted constraints to a gadget's
`Spec`; `byteTable_lookup_iff` is instantiated nowhere and its `hdiag` therefore
discharged nowhere; `FieldExpr.lower_spec` is satisfied by five grossly wrong
lowerings and does not compose; and G9 compares no types.

The lookup side, which R4a-6 found had no semantic theorem, has one in
`byteTable_lookup_iff` — `Gadgets.ByteTable.Contains t x` holds exactly when `x`
is one of the field elements the emitted `@Bytes` array holds. This paragraph
used to add that its canonicity hypothesis was "discharged from the compiler's
own registry check". It is not: nothing instantiates the theorem, so nothing
discharges its hypothesis.

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
  produced a spurious Lean target failure during S00.

## Next session

- **Packet: `doc/llzk/sessions/S24-finish-stage1.md`.** Four ordered deliverables,
  each making the next safer: wire the worktree lock into `e2e.sh`; execute S23
  to close X1 on the supported path; reproduce the gates from a clean checkout,
  which has never been done; and CI, which has never run on GitHub and needs
  authorization to push.
- **Claim the worktree first** — `bash scripts/llzk/worktree-lock.sh claim "..."`.
  Three sessions collided on 2026-08-01; `doc/llzk/CONCURRENCY.md` records what
  it cost. S21 checked for a free tree the informal way and was wrong.

Beyond S24, and not part of it:

- **A Clean-side change for D012.** The certificate cannot be tied to the
  circuit's own table while `Table.toRaw` erases the `Table`. Carrying it into
  `Lookup` is a change to Clean's core, with its own review. This is `GAPS.md`
  §1's second half and S24 explicitly does not close it.
- **The rest of `GAPS.md`.** §2 the renderer, §3 the chain to a gadget's `Spec`,
  §7 D017's reading of LLZK. Stage 1 closing does not close these.
- **Stage 2.** Subcircuits as named components alongside `@Main`, which is the
  shape D015 was chosen to be compatible with.
