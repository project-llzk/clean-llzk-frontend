# Clean → LLZK current state

Updated: 2026-08-01  
Active milestone: **Stage 1 repaired and re-reviewed** — all gates G0–G10 green
against the pinned tools  
Last accepted session: R4 — two independent reviews, and their repairs  
Integration branch: `clean-to-llzk/integration`  
Integration commit: recorded in `sessions/R4-independent-review.md` § Handoff  
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

Expected: `PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10` — 11 circuits, 30 input
vectors, both witgen backends, 2 renderer fixtures.

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
| G8 fail closed | PASS — 19 negative fixtures, one per rejection path, plus tool-version rejection |
| G9 the emitted `@constrain` **and** `@compute` are the circuit's | PASS — both preconditions of emission, so every circuit (D018, D020) |
| G10a LLZK analysis pipeline admits the module | PASS — all 13 |
| G10b SMT lowering | PASS — 9 lowered, 4 out of scope for a declared reason |

Every gate is checked to be falsifiable, and the checks are part of the gate
rather than notes about it:

- the witness gates, by `require_llzk_witgen_discriminates`, which runs
  `llzk-witgen` against a perturbed witness before the loop and aborts if it
  passes (R2-06);
- G3, G4 and G10, by `require_llzk_opt_discriminates`, which requires `llzk-opt`
  to reject a non-MLIR file — a shim answering only `--version` used to make all
  three vacuous while the harness printed PASS (R4b-2);
- G9, by `Test/Constraints.lean`, which perturbs the Clean side six ways and
  pins that the comparison goes red for each;
- G10a, by the control in `evidence/S08-S15/controls.txt`: a module whose root is
  not `@Main` fails it.

## What is still not established

One boundary, and one improvement. Everything else R4 named is either closed or
covered by another gate — see `review/R4-findings.md` for the risk-by-risk
verdict, each pinned by a control rather than asserted.

**D017 — the reading of LLZK — cannot be closed from this repository.**
`llzk-witgen`'s help text says it outright: *"llzk-witgen v1 ignores constrain()
and traps on bool.assert."* There is no executor for `@constrain` in the pinned
toolchain, and no formal LLZK semantics in Lean, so the assumption that
`constrain.eq` is equality and `constrain.in` is membership has no empirical
check and cannot acquire one here. Closing it means formalising LLZK, which is
VeIR's project (D003). The `@compute` half of the same reading *does* have
evidence: 30 vectors across two independent LLZK backends.

**S20 — the preservation theorem — is an improvement, not a gap in the
artifacts.** Every module `compile` returns has been compared against its circuit
on both sides, so a lowering bug yields a *refusal*, never a wrong module. S20
would make that refusal impossible rather than merely never-observed: better
robustness and diagnosis, not better soundness of what is emitted.

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

- **S20 — the lowering as a theorem.** Replace D018/D020's translation validation
  with a preservation theorem about `lower`: the `BuilderM` simulation argument.
  `Constraints.lean` and `WitnessCheck.lean` already fix the statements it has to
  prove, and it would close three of the four residual risks above by making the
  cross-check unnecessary rather than merely broader.
- **A Clean-side change for D012.** The certificate cannot be enforced while
  `Table.toRaw` erases the `Table`. Carrying it into `Lookup` is a change to
  Clean's core, with its own review.
- **Stage 2.** Subcircuits as named components alongside `@Main`, which is the
  shape D015 was chosen to be compatible with.
