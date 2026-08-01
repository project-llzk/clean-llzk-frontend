# Clean → LLZK decision log

## D001 — Host the first frontend in Clean

**Status:** accepted  
**Date:** 2026-07-31

Implement the first frontend as pure Lean under `Clean/Backend/LLZK/`. Emit a
small, deterministic textual LLZK subset and validate it with the pinned C++
LLZK 3.0 tools.

This avoids coupling Clean's Lean 4.30 toolchain to the project VeIR fork on
4.31-rc2 or upstream VeIR on 4.32.2.

## D002 — Use `alexanderlhicks/clean` as the project home

**Status:** accepted  
**Date:** 2026-07-31

The fork `alexanderlhicks/clean` owns the frontend implementation, fixtures,
conformance harness, decisions, pins, and cross-session handoffs.

Do not fork LLZK unless implementation uncovers a required LLZK dialect,
verifier, or witness-tool change.

## D003 — Keep VeIR non-blocking

**Status:** accepted  
**Date:** 2026-07-31

VeIR initially consumes the frozen `.llzk` fixture corpus as an independent
round-trip/checking track. A direct dependency is reconsidered only after
toolchains and required LLZK dialect coverage align.

## D004 — Fail closed on source semantics

**Status:** accepted  
**Date:** 2026-07-31

Clean's `NExpr` denotes unbounded natural arithmetic and is not generally field
arithmetic. Stage 1 recognizes only the explicitly justified Addition8
division/modulo shapes and rejects other natural expressions.

Lookup tables use an explicit backend registry because `RawTable` does not
retain concrete static rows.


## D005 — Make malformed LLZK unrepresentable in the emitter IR

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S03

The backend does not build LLZK text by concatenating strings, and it does not
model MLIR generically. It has a small typed IR that admits only the Stage-1
subset, and three shapes are ruled out by construction rather than by tests:

- `IR.Value` has a private constructor, so only `Builder.fresh` produces one. A
  lowering cannot reference an undefined SSA value or reuse one.
- `IR.Func.result : Option (Value × Ty)` is one field, so the rendered return
  type and the rendered `function.return` cannot disagree, and a body cannot be
  missing its terminator or carry two.
- `IR.StructDef` names `compute` and `constrain` as fields rather than holding a
  function list, so a struct that is not a valid LLZK component cannot be built.

Consequence: the analyzer's job shrinks to *source*-side questions (is this
Clean construct in the subset?). It never has to re-check emitter well-formedness.

## D006 — Derive `function.allow_non_native_field_ops` from the body

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S03

`Builder.function` inspects the statements actually emitted and adds the
attribute when any is non-native (`felt.uintdiv`, `felt.umod`). A caller cannot
forget it, and it is never added spuriously.

`function.allow_constraint` and `function.allow_witness` are deliberately *not*
emitted: `llzk-opt` infers them from the function's role and prints them back, so
emitting them by hand would only risk a round-trip difference.

## D007 — One-per-line parameters, one-line array literals

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S03

Rendered function parameters go one per line so that adding or removing one is a
one-line diff in a golden fixture; gate G2 is only useful if a golden diff is
readable. Constant-array initializers stay on one line however long, because a
lookup table is a single logical value and wrapping would make the layout depend
on the row count.
