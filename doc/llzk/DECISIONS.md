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

