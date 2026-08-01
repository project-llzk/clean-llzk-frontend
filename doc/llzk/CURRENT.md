# Clean → LLZK current state

Updated: 2026-08-01  
Active milestone: **Stage 1 repaired and re-reviewed** — all gates G0–G10 green
against the pinned tools  
Last accepted session: S19 — the witness side of G9  
Integration branch: `clean-to-llzk/integration`  
Integration commit: recorded in `sessions/S19-witness-side.md` § Handoff  
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
  - **S19**, the witness side of G9, plus the last two residuals: table
    certificates are now required to build a supported `Config`, and the corpus
    tests `Addition8FullCarry` outside its `Assumptions`.
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
- G9, by `Test/Constraints.lean`, which perturbs the Clean side six ways and
  pins that the comparison goes red for each;
- G10a, by the control in `evidence/S08-S15/controls.txt`: a module whose root is
  not `@Main` fails it.

## What is still not established

Two things, and neither is closable by more of this kind of work.

1. **D017 — the reading of LLZK.** That `felt.add` is `+`, `constrain.eq` is
   equality, `constrain.in` is membership, `felt.umod` reads its operands as
   canonical representatives, and `!felt.type<"babybear">` is `ZMod 2013265921`.
   Every emitted operation rests on it, and nothing in Lean settles it without a
   formal model of LLZK — which is VeIR's job (D003), not this backend's. G5–G7
   are the empirical evidence for the `@compute` half, on 30 vectors and two
   independent LLZK backends; there is no executor for `@constrain`, so its half
   has none.
2. **G9 validates each translation; it does not verify the translator** (D018,
   D020). A lowering bug surfaces as a refusal to compile, not as a compile-time
   impossibility. The refusal itself *is* tested — `verify` takes the module as
   an argument precisely so a test can hand it one circuit's module and another
   circuit's source — but a verified translator would make the refusal provably
   dead instead. Closing this is S20: a simulation argument over the `BuilderM`
   state monad.

Two smaller things, stated so they are not mistaken for gaps:

- The whole-vector witness statement — that `@compute` produces exactly
  `FlatOperation.dynamicWitnesses` — needs the block-prefix argument R2-03 is
  about, which `Analyze` enforces rather than proves. G9's witness half compares
  expressions cell by cell; G5–G7 cover the vector.
- No solver has run on an emitted module. G10 stops at admissibility and
  lowering because `llzk-smt-check` needs SMT-LIB that no pass in the pinned
  `llzk-opt` produces. That is a fact about the toolchain, recorded in `GATES.md`.

## Known constraints

- The frontend is a pure Lean backend in Clean which emits textual LLZK.
- VeIR is an independent consumer/proof track, not an initial dependency.
- Stage 1 accepts only the fail-closed subset in `ROADMAP.md`.
- The root component is always `@Main` (D015); the circuit's name is the
  artifact's file name.
- Heavy Nix and Lean builds must not run concurrently on this machine; doing so
  produced a spurious Lean target failure during S00.

## Next session

- **R4 — two independent adversarial reviews** were run against this tree, one
  on the proof track and one on the emitter and harness. Reconcile their
  findings; they are the first review of this work by anything other than the
  session that wrote it, which R3 correctly flagged as its own weakness.
- **S20 — the lowering as a theorem.** Replace D018/D020's translation validation
  with a preservation theorem about `lower`: the `BuilderM` simulation argument.
  `Constraints.lean` and `WitnessCheck.lean` already fix the statements it has to
  prove, and doing it would make both refusal branches provably dead.
- **Stage 2.** Subcircuits as named components alongside `@Main`, which is the
  shape D015 was chosen to be compatible with.
