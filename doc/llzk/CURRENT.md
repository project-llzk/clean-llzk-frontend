# Clean → LLZK current state

Updated: 2026-08-01  
Active milestone: **Stage 1 complete** — all gates G0–G8 green against the pinned tools  
Last accepted session: S02 — validate the emitted corpus against LLZK 3.0  
Integration branch: `clean-to-llzk/integration`  
Integration commit: filled in by the commit that follows this one  
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

Expected: `PASS: G0 G1 G2 G3 G4 G5 G6 G7` — 3 circuits, 16 input vectors, both
witgen backends.

## State

- Completed:
  - S00 control plane; S03 emitter IR and renderer; S04 analysis, layout and the
    assertion-only slice; S05 the natural division/modulo shapes; S06 tables and
    lookups; S07 the emitter command and harness; S01 tooling; S02 validation.
  - `Gadgets.Addition8FullCarry` compiles to LLZK, `llzk-opt` accepts and
    round-trips it, and both witgen backends reproduce Clean's witness on every
    recorded input.
- In progress: none.
- Blocked: none.

## Last green gates

Evidence under `doc/llzk/evidence/`.

| Gate | Result |
|---|---|
| G0 state and pins | PASS |
| G1 lint + `lake build --wfail Clean` (1823) + `lake build CleanTests` (1718) | PASS |
| G2 goldens: renderer, and three full emitted modules | PASS |
| G3 `llzk-opt` parse and verify | PASS — 3 modules |
| G4 `llzk-opt --verify-roundtrip` | PASS — 3 modules |
| G5 `llzk-witgen` interpreter | PASS — 16 vectors |
| G6 `llzk-witgen` execution engine | PASS — 16 vectors |
| G7 both backends vs Clean's own interpreter | PASS — carried by `--check-output` |
| G8 fail closed | PASS — eight negative fixtures, plus tool-version rejection |
| G9 proof | **not started** |

The witness gates were checked to be falsifiable, not just green: corrupting an
expected value, and injecting a one-off into Clean's witness computation, both
turn the harness red. See `doc/llzk/evidence/S02/gates.txt`.

## What is still not established

1. **Nothing checks the emitted constraints.** `llzk-witgen` executes `compute()`
   and ignores `constrain()`. G5–G7 show the two *witness generators* agree; no
   gate shows that the emitted `constrain.eq`/`constrain.in` capture Clean's
   assertions and lookups. This is the largest gap and is what S08 / G9 are for.
2. **Two semantic arguments are prose, not proof** — D011 (the natural
   division/modulo lowering) and D012 (that registry rows are the table's rows;
   the backend cannot check this, and `Gadgets.ByteTable` cannot use the
   `ofStatic` mitigation).
3. **No review session has run.** R0, R1 and R2 are outstanding; in particular
   nothing has been reproduced from a clean checkout.
4. **The input corpus is chosen, not exhaustive** — boundaries and Addition8's
   carry cases. See `LLZK.Corpus.corpus`.

## Known constraints

- The frontend is a pure Lean backend in Clean which emits textual LLZK.
- VeIR is an independent consumer/proof track, not an initial dependency.
- Stage 1 accepts only the fail-closed subset in `ROADMAP.md`.
- Heavy Nix and Lean builds must not run concurrently on this machine; doing so
  produced a spurious Lean target failure during S00.

## Next session

- Packet: R2 (Stage-1 acceptance from a clean checkout), then S08 (proof
  baseline).
- Objective for S08: executable semantics for the emitted subset, and the first
  preservation theorems — field-expression evaluation, assertion lowering, and
  the two natural shapes of D011. That closes gap 1 and gap 2 together.
- First command: `bash scripts/llzk/e2e.sh` from a fresh clone of the branch.
