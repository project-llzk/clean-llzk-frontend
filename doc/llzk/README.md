# Clean to LLZK frontend

This directory is the durable control plane for Clean's LLZK frontend. The
implementation lives in `Clean/Backend/LLZK/`; this guide separates the small
public reading path from the session and review record used to build it.

## What exists today

The frontend accepts a documented, fail-closed subset of flattened Clean
`FormalCircuit`s and emits a deterministic LLZK 3.0 module. The supported path
has five assurance layers:

1. Clean gadgets carry Lean soundness and completeness proofs against semantic
   specifications.
2. The frontend compares the typed module's constraints and witness program
   with the flattened Clean circuit before returning it; copy canonicalisation
   has a proved value-preserving invariant over the whole witness-program list.
3. The rendered `@constrain` surface is parsed back and compared with the typed
   module before artifact text is returned.
4. `llzk-opt` parses, verifies, round-trips, and analyzes each emitted artifact.
5. Both `llzk-witgen` backends are checked against Clean's witness interpreter
   over a boundary-oriented input corpus.

Stage 1 demonstrates that chain on `Addition8FullCarry`. The conformance corpus
contains 12 emitted modules and 33 input vectors. This is a strong vertical
slice, not broad library coverage: the measured coverage sweep currently finds
roughly seven compiling gadgets among approximately 128 top-level circuits, and
only the corpus has reached the external LLZK tools.

## Reading path

Read these in order:

1. [`PUBLIC-READINESS.md`](PUBLIC-READINESS.md) — the milestone for an
   organization-owned, presentable release candidate.
2. [`CURRENT.md`](CURRENT.md) — the exact repository state, last green evidence,
   and next action.
3. [`ROADMAP.md`](ROADMAP.md) — supported capability, measured coverage, and
   dependency order.
4. [`GAPS.md`](GAPS.md) — claims the project deliberately does not make.
5. [`ARCHITECTURE.md`](ARCHITECTURE.md) — the source-to-LLZK design.

For reproducibility and review:

- [`PINS.md`](PINS.md) records every accepted external revision and tool.
- [`GATES.md`](GATES.md) defines G0-G12 and their falsification controls.
- [`DECISIONS.md`](DECISIONS.md) records semantic and trust-boundary decisions.
- [`review/`](review/) contains adversarial findings and dispositions.
- [`evidence/`](evidence/) contains captured gate and probe results.
- [`sessions/`](sessions/) is the historical execution record; it is not the
  onboarding path.

## Reproduce the current milestone

First obtain the pinned LLZK tools using [`PINS.md`](PINS.md). Then, from the
repository root:

```bash
export LLZK_SESSION=manual-reproduction
export LLZK_OPT=/path/to/llzk-opt
export LLZK_WITGEN=/path/to/llzk-witgen
bash scripts/llzk/worktree-lock.sh claim "reproduce Clean to LLZK"
bash scripts/llzk/e2e.sh
```

The recorded Stage-1 result is:

```text
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
12 circuit(s), 33 input vector(s), both witgen backends
```

The worktree lock is part of the evidence protocol: the run rebuilds generated
artifacts, so its output is attributable only when one session owns the tree.

## Claim boundary

The strongest established generic result is that, subject to the named lookup
hypothesis and the gadget's assumptions, satisfaction of the compiled typed
module's constraints implies the gadget's `Spec`. A separate renderer theorem
ties its protected constraint surface to the typed module, and witness-side
invariants prove copy canonicalisation value-preserving stepwise and as a whole.
LLZK's concrete semantics remain outside these Lean theorems. `GAPS.md` is
authoritative if a summary and a boundary ever disagree.
