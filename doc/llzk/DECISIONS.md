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

## D008 — Outputs get their own public members

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S04

A Clean circuit output is an arbitrary `Expression`, not necessarily a witness
cell: it may be an input, a constant, or a sum. The backend therefore gives each
output field element its own `{llzk.pub}` member `@out{j}`, writes it in
`@compute`, and constrains it equal to the lowered expression in `@constrain`.

Alternative considered: mark "the witness cell an output points at" as
`{llzk.pub}`. Rejected because it needs a fallback for every output that is not
exactly a witness variable, and because it makes the public JSON key names depend
on the witness layout.

The extra `constrain.eq` per output does not change what the constraint system
proves — it defines a fresh cell as equal to an expression over existing ones.
What it buys is that `llzk-witgen --output-scope=public` reports exactly the
circuit's outputs under stable names, which is what gate G7 diffs against Clean.

## D009 — Recognize into a closed language, then lower totally

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S04

`Analyze` does not *validate* a Clean circuit and hand the original on. It
*translates* it into `Recognized`, built from `FieldExpr` — a closed language
containing only what the backend can emit. The lowering consumes `Recognized` and
is total apart from one genuine failure (an expression naming a circuit variable
nothing defines).

Consequences:

- There is exactly one place that decides what is in the subset. The lowering has
  no "unsupported" branch to keep in sync.
- `analyze` and `compile` share one implementation: `analyze` is the diagnostics
  of the same recognition pass, so they cannot disagree about what is accepted.
- Growing a capability is: one `FieldExpr` constructor, one case per recognizer,
  one case in `lower`, one positive and one negative fixture.
- The semantics theorems planned for P5 get a small closed language to talk
  about, instead of a predicate carved out of Clean's much larger witness IR.

Diagnostics are collected across all operations rather than stopping at the
first. Each operation is recognized independently, so a rejection cannot cascade.

## D010 — The field name and its prime travel together

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S04

`Config.field` is a `FieldSpec` (name plus prime) drawn from `FieldSpec.registry`,
not a bare string, and `Analyze` rejects a circuit whose `FiniteField.size` is not
that prime. A wrong field choice is therefore a diagnostic rather than arithmetic
silently performed in the wrong field.

The registry is transcribed from `lib/Util/Field.cpp`, `Field::initKnownFields`,
at the pinned LLZK revision. Adding a field means adding it there, with its
prime — not passing a new string.

## D011 — Match the natural division/modulo shapes whole, with a literal divisor

**Status:** accepted
**Date:** 2026-08-01
**Enacted by:** S05

`Witgen.NExpr` denotes unbounded `ℕ`. Lowering natural arithmetic to `felt.*`
piecewise is therefore wrong in general, because field reduction changes
intermediate values. The backend recognizes exactly two *whole* shapes:

```
ofNat (mod (val x) (const c))  ->  felt.umod    [x], felt.const c
ofNat (div (val x) (const c))  ->  felt.uintdiv [x], felt.const c
```

Matching the whole shape rather than `val`, `mod` and `ofNat` separately is what
makes this sound: no natural value escapes the pattern, so there is no
intermediate that could have exceeded the field.

The divisor is a `Nat` literal in `FieldExpr`, not a nested expression, so two
side conditions can be checked at recognition time:

- `c ≠ 0`. Lean's `Nat` division and modulo by zero are total (both `0`); LLZK's
  are not. Accepting this would be a silent semantic difference.
- `c < p`. `felt.const c` denotes `c mod p`, so a divisor at or above the prime
  would become a different number.

Given those, the lowering is faithful for the prime fields in
`FieldSpec.registry`: `FiniteField.val x` is the canonical representative in
`[0, p)`, which is exactly the operand interpretation LLZK's `umod`/`uintdiv`
use, and the result re-enters the field through `FiniteField.fromNat`, whose
`val_fromNat` law applies because `val x % c` and `val x / c` are both at most
`val x`, hence below the field size.

This argument is prose, not a proof. Turning it into one is a P5 obligation, and
it is the reason `FieldExpr` is a small closed language (D009): there is
something tractable to state it about.

Every other `NExpr` shape stays rejected. The general treatment — `NExpr.val` to
`cast.toindex`, natural arithmetic on `index`, `FExpr.ofNat` to `cast.tofelt` —
needs an index bounds policy and LLZK interpreter support that do not exist yet,
and is deliberately not an implicit backlog item.
