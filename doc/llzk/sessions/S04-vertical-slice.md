# S04 — Analysis, layout, and the assertion-only vertical slice

Status: accepted  
Depends on: S03 (S01 and S02 still deferred — see Deviations)  
Base integration commit: `b75a5125` (S03 accepted)  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Compile a real `FormalCircuit` to textual LLZK end to end, and refuse — before
any text exists — everything outside the Stage-1 subset.

## Must read

- `doc/llzk/ARCHITECTURE.md` §4.4, §4.6, §5, §6.
- `doc/llzk/DECISIONS.md` D005–D010.

## Deliverables

- `Basic.lean` — `Diagnostic`, the LLZK field registry, `Config`.
- `Expression.lean` — `FieldExpr`, the closed accepted language, and its lowering.
- `Witness.lean` — witness-program recognition and the capability boundary.
- `Analyze.lean` — `Source`, `Recognized`, `recognize`, `analyze`.
- `Circuit.lean` — layout, `@compute`/`@constrain` lowering, `compile`, `emit`.
- `Test/Circuit.lean` — one positive and three negative goldens.

## Non-goals

- Natural division/modulo witness shapes (S05).
- Lookup tables and `constrain.in` from a circuit (S06); the IR and renderer
  already support them, and the renderer golden covers them.
- A user-facing command (S07).

## Acceptance gates

- G1: lint, `lake build --wfail Clean`, `lake build CleanTests`. PASS.
- G2: both goldens. PASS.
- G8: three negative fixtures pin exact diagnostics. PASS.

G3–G7 are **not** claimed. No LLZK tool has seen this output.

## Evidence

`doc/llzk/evidence/S04/gates.txt`

## What the slice produces

`multiply` — two inputs, one witness cell, one assertion, one output, proved
sound and complete — compiles to a single `@Multiply` component with members
`@w0 {signal}` and `@out0 {llzk.pub}`, an `@compute` that multiplies the two
arguments and writes both members, and an `@constrain` that reads them back,
emits `constrain.eq` for the assertion against `felt.const 0`, and one more for
the output. The exact text is pinned in `Test/Circuit.lean`.

Note the constant `2013265920` in the constrained expression: Clean desugars
`a - b` to `a + (-1) * b`, and `-1` in Babybear is `p - 1`. That is faithful, not
a defect, but it is the kind of thing a reviewer should recognize.

## Handoff

- Changes made: six new backend modules and one new test module; `Print.lean`
  restructured around line blocks (see Deviations); one import line in each of
  `Clean.lean` and `Clean/Test.lean`.
- Decisions made: D008–D010.
- Deviations:
  - **S04 ran before S01 and S02**, for the same reason S03 did. The consequence
    is unchanged and compounding: two increments of emitter syntax are now
    unvalidated by any LLZK tool. S02 should validate the two goldens in this
    branch *first*, before writing a fresh handwritten fixture — the emitter's
    output is now the more useful subject.
  - `Print.lean` was restructured during S04: the original `Lines` accumulator
    decided blank-line placement at each call site and emitted a stray blank line
    for a module with no globals. Each construct now renders to an unindented
    `Array String` and `joinBlocks` owns separation. The S03 golden is byte-for-
    byte unchanged, which is the evidence the restructure was behaviour-
    preserving.
  - `IR.lean` gained `Builder.computeFunction`/`constrainFunction` and lost the
    general `Builder.function`. The two component builders hand the body `%self`
    and the input values directly, so no caller has an out-of-range index case;
    `Func`'s constructor is now private, so a function that is neither a
    `@compute` nor a `@constrain` cannot be built. `Value` lost its `Inhabited`
    instance, which would have let a caller conjure a silently wrong SSA value.
- Blockers: none for S04. S01 remains blocked on `sudo systemctl restart
  nix-daemon`; the trust key itself has been corrected.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: restart the Nix daemon, then run S01 and S02 — validating
  the two existing goldens with `llzk-opt` before anything else.
