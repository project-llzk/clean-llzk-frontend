import Clean.Circuit.WitnessIR
import Clean.Backend.LLZK.Expression

/-!
# Recognizing witness programs

Clean's witness IR is far larger than what this backend emits, so this is where
the Stage-1 capability boundary actually lives. Everything the recognizers here
reject is rejected *before* any LLZK text exists, which is what makes the backend
fail closed.

The accepted set is deliberately the smallest one that carries a real circuit,
and every rejection names the construct and says what it would take to support
it. Growing the set means adding a case here, a `FieldExpr` constructor, and a
fixture — see `doc/llzk/ROADMAP.md`.

Accepted today:

* programs of the form `.ir [] (.lit es)` — no `let`-steps, a literal output
  vector;
* within an element: `.expr`, `.const`, `.add`, `.mul`, and the two u64
  division/modulo shapes described below.

Everything else — `.native` closures, `let`-steps,
`mapRange`/`envRange`/`bitsOf`/`append` outputs, `inv`, `ite`, `listGet`,
`dataGet`, `hintGet`, and any other `ofU64` shape — is rejected.

## The two accepted u64 shapes

The upstream witness IR now uses wrapping `Witgen.U64Expr`. S25 preserves the
accepted language by recognizing only the two shapes the old backend accepted,
and only as a unit:

```
ofU64 (mod (val x) (const c))  ↦  felt.umod    ⟦x⟧, felt.const c
ofU64 (div (val x) (const c))  ↦  felt.uintdiv ⟦x⟧, felt.const c
```

Matching the whole shape — rather than `val`, `mod` and `ofU64` separately — is
what keeps the accepted bridge narrow. No intermediate `U64Expr` escapes the
pattern; the field-size boundary needed for semantic fidelity is stated below.

Two side conditions are checked at recognition time, which is why the divisor
must be a literal:

* `c ≠ 0`. Lean's `Nat` division and modulo by zero are total (both give `0`),
  LLZK's are not; accepting this would be a semantic difference.
* `c < p`. `felt.const c` denotes `c mod p`, so a divisor at or above the prime
  would silently become a different number.

Given those, the lowering is faithful when `FiniteField.size F ≤ 2^64`:
`U64Expr.val` does not truncate any representative, and the result re-enters the
field through `FiniteField.fromNat`. This covers babybear, koalabear,
mersenne31, and goldilocks. On bn254 and grumpkin the source bridge truncates
while LLZK's felt operation sees the full representative; S25 records that
semantic boundary as D026 and `WExpr.eval_ofWitgen` requires the size bound.

**That last paragraph has a side condition `FiniteField` does not carry**, and
until S18 it was not stated anywhere. `FiniteField` abstracts over prime *and*
binary fields, and its laws — `val_lt`, `val_injective`, `val_fromNat`,
`val_zero`, `val_one` — do not say that `val` is the *ring* representative.
`Analyze.checkField` pins `FiniteField.size F` only, and size `p` forces
`F ≅ 𝔽_p` without forcing this particular `val` to be that isomorphism. The same
assumption underlies `FieldExpr.ofExpression`'s `.const c ↦ felt.const (val c)`,
and gate G7 could not detect a violation because `Differential.witness` goes
through the same `val`/`fromNat`.

It is now a hypothesis rather than a hope: every recognizer here requires
`LLZK.CanonicalRepr F`, whose two laws pin `val` to the canonical representative
(`CanonicalRepr.val_natCast` derives that). A field that does not carry it is a
type error, not silently wrong arithmetic — the same treatment D010 gives a wrong
prime. See R2-05, D011 and `Clean/Backend/LLZK/Field.lean`.

## The witness-block environment

`FlatOperation.dynamicWitnesses` folds with `acc ++ op.dynamicWitness hint acc`:
a `.witness m` block computes all `m` of its cells against the environment
*before* the block. A cell reading a circuit variable allocated by its own block
therefore reads `0` in Clean, while a straightforward `@compute` lowering — which
writes each cell as it goes — would read the computed value. Clean names the
discipline that rules this out `Operations.ComputableWitnesses`; the backend
enforces it here, by refusing any block cell that reads at or above the block's
base offset. See R2-03.
-/

namespace LLZK

/-- Name a witness-IR constructor in a diagnostic, and say what supporting it
would require. Kept exhaustive rather than falling back to a generic message, so
a rejection tells the reader which roadmap item they are hitting.

Total over all eleven constructors even though `ofFExpr` handles five of them
before reaching here: exhaustiveness is what makes adding a constructor to
`Witgen.FExpr` a compile error in this module rather than a silent "unsupported". -/
private def describeFExpr {F : Type} : Witgen.FExpr F → String
  | .expr _ => "a circuit expression"
  | .const _ => "a field constant"
  | .localVar _ => "`localVar` (a reference to a `let`-step)"
  | .add _ _ => "an addition"
  | .mul _ _ => "a multiplication"
  | .inv _ => "`inv` (field inverse); it needs `felt.inv`, which is a later increment"
  | .ofU64 _ =>
    "`ofU64` on a u64 expression that is not one of the two recognized \
     division/modulo shapes"
  | .ite _ _ _ => "`ite` (a conditional); it needs `scf.if`, which is a later increment"
  | .listGet _ _ => "`listGet` (a constant-list read); it needs the array dialect"
  | .dataGet _ _ _ _ => "`dataGet` (a read of committed prover data)"
  | .hintGet _ _ _ _ => "`hintGet` (a read of an uncommitted prover hint)"

/-- Name a u64-sorted witness-IR constructor. Exhaustive for the same reason
`describeFExpr` is: a rejection should say which construct was hit, and `U64Expr`
was one of the two places that fell back to a generic message. -/
private def describeU64Expr {F : Type} : Witgen.U64Expr F → String
  | .const _ => "a u64 constant"
  | .val _ => "`val` (the truncating field-to-u64 bridge) applied on its own"
  | .idx => "`idx` (a `mapRange` loop index)"
  | .localVar _ => "`localVar` (a reference to a `let`-step)"
  | .add _ _ => "a u64 addition"
  | .mul _ _ => "a u64 multiplication"
  | .div _ _ => "a u64 division whose shape is not `div (val x) (const c)`"
  | .mod _ _ => "a u64 modulo whose shape is not `mod (val x) (const c)`"
  | .land _ _ => "`land` (bitwise and)"
  | .lor _ _ => "`lor` (bitwise or)"
  | .lxor _ _ => "`lxor` (bitwise exclusive or)"
  | .shiftL _ _ => "`shiftL` (a left shift)"
  | .shiftR _ _ => "`shiftR` (a right shift)"
  | .ite _ _ _ => "`ite` (a conditional); it needs `scf.if`, which is a later increment"

/-- Name the condition at the root of a rejected field `ite`. Keeping this
exhaustive makes upstream condition constructors fail compilation here until
the backend gives them an explicit boundary. -/
private def describeBExpr {F : Type} : Witgen.BExpr F → String
  | .true => "`true`"
  | .false => "`false`"
  | .feq _ _ => "`feq` (field equality)"
  | .neq _ _ => "`neq` (u64 equality)"
  | .lt _ _ => "`lt` (u64 less-than)"
  | .flt _ _ => "`flt` (field-representative less-than)"
  | .bit _ _ => "`bit` (a field-representative bit test)"
  | .not _ => "`not`"
  | .and _ _ => "`and`"

/-- Name a `let`-step's constructor, for the same reason. -/
private def describeStep {F : Type} : Witgen.Step F → String
  | .letF _ => "`letF` (a field-sorted `let`-step)"
  | .letU _ => "`letU` (a u64-sorted `let`-step)"

namespace FieldExpr

variable {F : Type} [FiniteField F]

/-- Check the side conditions that make a literal divisor safe to lower.

`prime` is the configured field's prime. See the module docstring for why each
condition is necessary. -/
private def checkDivisor (context : String) (operation : String) (prime divisor : Nat) :
    Except Diagnostic Unit :=
  if divisor = 0 then
    .error { context
             message := s!"witness {operation} has divisor 0; Lean's natural {operation} by zero \
                           is total but LLZK's is not, so this shape is refused" }
  else if divisor ≥ prime then
    .error { context
             message := s!"witness {operation} has divisor {divisor}, which is not below the \
                           field prime {prime}; `felt.const` would reduce it modulo the prime" }
  else .ok ()

/-- Check that a `FieldExpr` can be lowered faithfully: every constant is already
a canonical representative, and every literal divisor satisfies D011's two side
conditions.

Everything `ofFExpr` produces satisfies this by construction, so on the
`recognize` path the check never fires. `Recognized` is a public structure
though, and `Circuit.lowerRecognized` accepts one built by hand — where until now
nothing checked it at all, because the conditions were enforced *by the
recognizer* rather than *before the lowering*. R5c walked through that gap twice:

* `.uintdiv (.var 0) 0` emits `felt.uintdiv %v0, %zero`, which `llzk-opt` parses,
  verifies, round-trips and product-programs without complaint, and which
  `llzk-witgen` then traps on. Text produced with an empty diagnostic array that
  no static gate rejects.
* `.umod (.var 0) (p + 5)` emits `felt.const 2013265926`, which LLZK reduces to
  `5`, so the module computes `7 % 5 = 2` where the caller wrote `7 % (p + 5) =
  7`. Silent, on both witgen backends, with `llzk-opt` clean.

Both are now refused before any text exists. `Circuit.lower` runs this, so the
check sits below every door rather than beside one of them. -/
def checkLowerable (prime : Nat) (context : String) :
    FieldExpr → Except Diagnostic Unit
  | .var _ => .ok ()
  | .const c =>
    if c < prime then .ok ()
    else .error { context
                  message := s!"constant {c} is not below the field prime {prime}; \
                                `felt.const` reduces its operand modulo the prime, so the \
                                emitted module would not denote what this expression says" }
  | .add a b | .mul a b => do
    checkLowerable prime context a
    checkLowerable prime context b
  | .uintdiv a d => do
    checkDivisor context "division" prime d
    checkLowerable prime context a
  | .umod a d => do
    checkDivisor context "modulo" prime d
    checkLowerable prime context a

/-- Recognize a field-sorted witness expression.

`.expr` delegates to `ofExpression`, which is total, so an embedded circuit
expression is always accepted; the arithmetic constructors recurse; the two
u64 division/modulo shapes are matched whole; everything else is refused by
name. -/
def ofFExpr [CanonicalRepr F] (prime : Nat) (context : String) :
    Witgen.FExpr F → Except Diagnostic FieldExpr
  | .expr e => .ok (ofExpression e)
  | .const c => .ok (.const (FiniteField.val c))
  | .add a b => return .add (← ofFExpr prime context a) (← ofFExpr prime context b)
  | .mul a b => return .mul (← ofFExpr prime context a) (← ofFExpr prime context b)
  | .ite c _ _ =>
    .error { context
             message := "unsupported witness expression: `ite` with " ++ describeBExpr c
                        ++ "; conditionals need `scf.if`, which is a later increment" }
  | .ofU64 (.mod (.val x) (.const c)) => do
    checkDivisor context "modulo" prime c.toNat
    return .umod (← ofFExpr prime context x) c.toNat
  | .ofU64 (.div (.val x) (.const c)) => do
    checkDivisor context "division" prime c.toNat
    return .uintdiv (← ofFExpr prime context x) c.toNat
  | .ofU64 n =>
    .error { context
             message := "unsupported witness expression: `ofU64` applied to " ++ describeU64Expr n
                        ++ "; only the two recognized division/modulo shapes are lowered" }
  | e => .error { context, message := "unsupported witness expression: " ++ describeFExpr e }

end FieldExpr

namespace Witness

variable {F : Type} [FiniteField F] {m : Nat}

/-- Recognize the output of a witness program: one expression per witness cell.

`[CanonicalRepr F]` is written into every signature in this namespace rather than
left to a `variable`. D019 claimed the class was required at every recognizer;
R4a-1 found it in *zero* elaborated signatures, because a `variable [C F]` binder
is dropped unless the instance is used in the declaration, and R5b-4 found the
same pattern still here after that repair. An explicit binder cannot be dropped,
and `#check` on these names is how the claim stays true. -/
private def ofVExpr [CanonicalRepr F] (prime : Nat) (context : String) :
    {n : Nat} → Witgen.VExpr F n →
    Except Diagnostic (Array FieldExpr)
  | _, .lit es => es.toArray.mapM (FieldExpr.ofFExpr prime context)
  | _, .mapRange _ _ =>
    .error { context
             message := "witness output is a `mapRange` loop; only literal output vectors are \
                         supported (unrolling or `scf.for` is a later increment)" }
  | _, .append _ _ =>
    .error { context
             message := "witness output is an `append`; only literal output vectors are \
                         supported" }
  | _, .envRange _ =>
    .error { context
             message := "witness output is an `envRange`; only literal output vectors are \
                         supported" }
  | _, .bitsOf _ =>
    .error { context
             message := "witness output is a `bitsOf`; structural bit decomposition is S26, \
                         not part of this compatibility bump" }

/-- Reject a cell that reads a circuit variable its own block allocates.

`base` is the block's first circuit variable. Clean evaluates every cell of a
`.witness m` block against the environment before the block, so such a read is
`0` on Clean's side and the computed value on LLZK's. Refusing it is what makes
the emitted `@compute` agree with `FlatOperation.dynamicWitnesses` for every
accepted shape, rather than only for the single-cell blocks the corpus happens to
contain. -/
private def checkBlockLocal (context : String) (base : Nat) (cells : Array FieldExpr) :
    Except Diagnostic Unit := do
  for (cell, k) in cells.zipIdx do
    if let some index := cell.firstVarAtLeast base then
      throw { context
              message := s!"cell {k} reads circuit variable {index}, which this same witness \
                            block allocates (the block starts at variable {base}); Clean \
                            evaluates a block against the environment *before* it, so that read \
                            is 0 there and would be the computed value here. Split the block, or \
                            read only inputs and cells from earlier blocks" }
  return ()

/-- Recognize a whole witness program as one expression per cell it produces.

`base` is the circuit variable the block's first cell defines. The returned array
has one entry per witness cell, in allocation order. -/
def recognize [CanonicalRepr F] (prime : Nat) (context : String) (base : Nat) :
    Witgen.WitgenIR F m → Except Diagnostic (Array FieldExpr)
  | .native _ =>
    .error { context
             message := "witness is a native Lean closure, which cannot be exported; port it to \
                         the witness IR (see doc/witgen-authoring.md)" }
  | .ir steps out =>
    match steps with
    | [] => do
      let cells ← ofVExpr prime context out
      checkBlockLocal context base cells
      return cells
    | step :: rest =>
      .error { context
               message := s!"witness program starts with {describeStep step} and has \
                             {rest.length + 1} `let`-step(s) in total; only step-free programs \
                             are supported" }

end Witness
end LLZK
