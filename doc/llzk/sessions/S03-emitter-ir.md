# S03 — Backend-local IR and deterministic renderer

Status: accepted  
Depends on: S00 (S01 and S02 deferred — see Deviations)  
Base integration commit: `003874ac` (S00 accepted)  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

A typed emitter model for the Stage-1 LLZK subset, plus a deterministic renderer,
with a golden test that pins the exact concrete syntax. No Clean circuit is
walked.

## Must read

- `doc/llzk/ARCHITECTURE.md` §5 (the Stage-1 LLZK contract) and §6.
- `doc/llzk/GATES.md`.

## Allowed scope

- `Clean/Backend/LLZK/IR.lean`, `Print.lean`, `Test/Print.lean` (new).
- `Clean.lean`, `Clean/Test.lean` (one import line each).

## Deliverables

- `IR.lean` — the typed emitter model and its SSA builder.
- `Print.lean` — the single place that knows LLZK's concrete syntax.
- `Test/Print.lean` — a `#guard_msgs` golden covering every IR constructor.

## Non-goals

- Walking a Clean circuit, analysis, diagnostics, `Config` (all S04).
- Running `llzk-opt` on the output (needs S01).

## Acceptance gates

- G1: `python3 scripts/check-consecutive-empty-lines.py`,
  `lake build --wfail Clean`, `lake build CleanTests`.
- G2: the `#guard_msgs` golden in `Clean/Backend/LLZK/Test/Print.lean`.

Gates G3–G7 are **not** claimed. The rendered text has never been shown to an
LLZK tool. Its syntax was derived by reading fixtures in the pinned LLZK
revision, not by running the pinned binaries.

## Evidence

`doc/llzk/evidence/S03/gates.txt`

## Design decisions

Recorded as D005–D007 in `DECISIONS.md`. In short, the IR makes three classes of
malformed output unrepresentable rather than merely untested:

- `Value` has a private constructor, so a lowering cannot name an undefined SSA
  value or reuse one; only `Builder.fresh` produces values.
- `Func` carries its result as a single `Option (Value × Ty)`, so the rendered
  return type and the returned value cannot disagree, and a body cannot be
  missing its terminator or carry two.
- `StructDef` names `compute` and `constrain` as separate fields rather than
  holding a function list, so a struct that is not a valid LLZK component cannot
  be built.

`Builder.function` derives `function.allow_non_native_field_ops` from the
statements actually emitted, so `felt.uintdiv`/`felt.umod` cannot be rendered
into a function that has not declared them.

## Handoff

- Changes made: three new modules under `Clean/Backend/LLZK/`, plus one import
  line in each of `Clean.lean` and `Clean/Test.lean` so CI covers them.
- Decisions made: D005–D007.
- Deviations: **S03 ran before S01 and S02.** The critical path in
  `ORCHESTRATION.md` §9 is S00 → S01 → S02 → R0 → S03. S01 stalled on a machine
  trust change outside this session's authority (see
  `evidence/S01/substituter-diagnosis.md`), so S03 — whose gates need no LLZK
  tools — was brought forward instead of idling. The consequence is that S03's
  concrete syntax is *read from* the pinned LLZK revision's own test fixtures
  rather than *confirmed by* the pinned binaries. S02 must therefore treat the
  renderer output as unvalidated and is expected to correct it; R0 must review
  S03's syntax against the tools, not only against the fixtures.
  `Basic.lean` was also **not** created, though `ORCHESTRATION.md` lists it in
  S03: everything it would hold (`Diagnostic`, `Config`, `ExportTable`) is first
  used by S04, and adding unused declarations now would be dead code.
- Blockers: none for S03. S01 remains blocked on `sudo systemctl restart
  nix-daemon`.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: once the Nix daemon has been restarted, run S01
  (`bash scripts/llzk/doctor.sh --require-llzk` after exporting `LLZK_OPT` and
  `LLZK_WITGEN`), then S02.
