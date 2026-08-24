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
3. The rendered globals, members, constraint parameters, and complete
   `@constrain` body are parsed back and compared with the typed module before
   artifact text is returned.
4. `llzk-opt` parses, verifies, round-trips, and analyzes each emitted artifact.
5. Both `llzk-witgen` backends are checked against exact expectations in
   full-witness and public-output scopes over a boundary-oriented input corpus:
   internal cells are Clean-derived, while promoted Xor32/BLAKE3.G outputs are
   fixed independent references first checked equal to Clean.

Stage 1 demonstrates that chain on `Addition8FullCarry`; Xor32 and exact
`BLAKE3.G 0 1 2 3` are the promoted bitwise headlines. `EXAMPLES.md` derives
the exact conformance-corpus counts from Lean. This is a strong vertical slice,
not broad library coverage: the checked 12-gadget sweep currently has exactly
10 compile-capable rows among approximately 128 top-level circuits, and only
the corpus has reached the external LLZK tools.

## Reading path

Read these in order:

1. [`EXAMPLES.md`](EXAMPLES.md) — the generated, gate-checked public showcase.
2. [`CURRENT.md`](CURRENT.md) — the exact repository state, last green evidence,
   and next action.
3. [`ROADMAP.md`](ROADMAP.md) — supported capability, measured coverage, and
   dependency order.
4. [`GAPS.md`](GAPS.md) — claims the project deliberately does not make.
5. [`ARCHITECTURE.md`](ARCHITECTURE.md) — the source-to-LLZK design.

For reproducibility and review:

- [`PUBLIC-READINESS.md`](PUBLIC-READINESS.md) is the organization-publication
  acceptance contract.
- [`PUBLICATION.md`](PUBLICATION.md) prepares the organization metadata,
  protection, CI, and security settings without changing GitHub state.
- [`PINS.md`](PINS.md) records every accepted external revision and tool.
- [`GATES.md`](GATES.md) defines G0-G12 and their falsification controls.
- [`DECISIONS.md`](DECISIONS.md) records semantic and trust-boundary decisions.
- [`review/FRONTEND-AUDIT-2026-08-22.md`](review/FRONTEND-AUDIT-2026-08-22.md)
  is the completed pre-R8 frontend audit; its dated R8 erratum records why its
  later first frozen candidate was rejected.
- [`evidence/R8-2026-08-23/README.md`](evidence/R8-2026-08-23/README.md)
  records the completed replacement repair and local R8 pass on exact code
  candidate `193ec342`; publication remains a separate decision.
- [`review/`](review/) contains adversarial findings and dispositions.
- [`evidence/`](evidence/) contains captured gate and probe results.
- [`sessions/`](sessions/) is the historical execution record; it is not the
  onboarding path.

## Reproduce the current milestone

First obtain the pinned LLZK tools using [`PINS.md`](PINS.md). Then, from the
repository root:

```bash
(
  set -e
  export LLZK_SESSION="manual-reproduction-${BASHPID}"
  export LLZK_OPT=/path/to/llzk-opt
  export LLZK_WITGEN=/path/to/llzk-witgen
  bash scripts/llzk/worktree-lock.sh claim "reproduce Clean to LLZK"
  trap 'bash scripts/llzk/worktree-lock.sh release' EXIT
  bash scripts/llzk/e2e.sh
  bash scripts/llzk/worktree-lock.sh release
  trap - EXIT
)
```

The local R8 result on exact clean code candidate `193ec342` is:

```text
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
17 corpus module(s), 67 input vector(s), both witgen backends,
full-witness and public output scopes; 2 renderer fixtures;
G10a 19/19, G10b 10 lowered / 9 declared out of scope, G11 187
```

For historical comparison, the Phase-X result on `06b80f2f` was:

```text
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
16 circuit(s), 61 input vector(s), both witgen backends,
full-witness and public output scopes
```

For historical comparison, the recorded pre-Xor32 result was:

```text
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
15 circuit(s), 51 input vector(s), both witgen backends
```

The worktree lock is part of the evidence protocol: the run rebuilds generated
artifacts, so its output is attributable only when one session owns the tree.

## Claim boundary

The strongest established generic result is that, subject to the named lookup
hypothesis and the gadget's assumptions, satisfaction of the compiled typed
module's constraints implies the gadget's `Spec` for the typed output
reconstructed from that module assignment's ordered public `@out{j}` members.
A separate renderer theorem
ties its protected globals, members, constraint parameters, and complete
`@constrain` body to the typed module; both backends also execute the public
output contract. Witness-side
invariants prove copy canonicalisation value-preserving stepwise and as a whole.
LLZK's concrete semantics remain outside these Lean theorems. `GAPS.md` is
authoritative if a summary and a boundary ever disagree.
