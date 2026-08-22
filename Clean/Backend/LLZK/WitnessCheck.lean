import Clean.Backend.LLZK.Constraints
import Clean.Backend.LLZK.Certificate

/-!
# The witness side of G9: does the emitted `@compute` compute what Clean does?

`Constraints.lean` does this for `@constrain`. This is the other half, and until
S19 it was the last part of the pipeline with no check of its own: `@compute` was
covered by G5–G7 — the two `llzk-witgen` backends agreeing with Clean's
interpreter on the recorded input vectors (45 as of S26) — and by nothing else.
A few dozen vectors is
evidence, not a statement about all inputs.

The shape is the same as the constraint side, and so are its limits:

* `WExpr.ofSource` reads the **Clean** circuit's witness programs and output
  expressions, and `eval_ofWitgen` proves that reading preserves
  `Witgen.FExpr.eval` — Clean's own semantics.
* `WExpr.ofModule` reads the **emitted** `@compute` as data.
* The two are compared, and the comparison is a precondition of emission (D018),
  so it holds for every circuit rather than for the corpus.

## Why a tree and not a polynomial

`@constrain` is polynomial, so a normal form absorbs the difference between
`x*y` and `y*x`. `@compute` is not: natural division/modulo, bitwise operations,
and shifts are non-native operations with no polynomial normal form.
The comparison is therefore syntactic on trees, which is sound but stricter — two
computations that are equal but differently shaped would be reported as a
mismatch. That is fail-closed, and in practice the shapes match because both
readers are structural over the same source.

## Where the LLZK reading enters

`WExpr.eval`'s non-field cases *are* the D017 reading: LLZK applies natural
division/modulo, bitwise operations, and unmasked shifts to canonical felt
representatives, then re-enters the field. `eval_ofWitgen` proves that D033's
independent, bound-checked source reader denotes Clean's `U64Expr.eval` for
every admitted tree. `CanonicalRepr` (D019) supplies the prime-field laws for
u64 add/mul; the checked `.val` rule prevents UInt64 truncation.

## What this does not do

It compares the *expressions*, cell by cell. Lifting that to
"the emitted `@compute` produces the vector `FlatOperation.dynamicWitnesses`
produces" additionally needs the block-prefix argument R2-03 is about — which
`Analyze` now enforces rather than proves. G5–G7 remain the evidence for the
whole-vector statement.
-/

namespace LLZK

/-- The comparison language for `@compute`.

`cell i` is Clean circuit variable `i`: an input when `i < inputSize`, otherwise
witness cell `i - inputSize`. Divisors are literals, for the reason D011 gives. -/
inductive WExpr where
  | cell (i : Nat)
  /-- A felt constant, as its canonical representative. -/
  | const (n : Nat)
  | add (a b : WExpr)
  | mul (a b : WExpr)
  | uintdiv (a : WExpr) (divisor : Nat)
  | umod (a : WExpr) (divisor : Nat)
  | u64Bin (op : U64BinOp) (a b : WExpr)
deriving DecidableEq, Repr, Inhabited

namespace WExpr

variable {F : Type} [FiniteField F]

/-- The meaning of a compute expression.

The non-field cases are the D017 reading of the corresponding LLZK operations:
operands are canonical representatives, the operation is on naturals, and the
result re-enters the field. The shift cases do not mask the count modulo 64;
D033's source reader proves it is below 64 before admitting a `U64Expr`. -/
def eval (σ : Nat → F) : WExpr → F
  | .cell i => σ i
  | .const n => FiniteField.fromNat n
  | .add a b => eval σ a + eval σ b
  | .mul a b => eval σ a * eval σ b
  | .uintdiv a d => FiniteField.fromNat (FiniteField.val (eval σ a) / d)
  | .umod a d => FiniteField.fromNat (FiniteField.val (eval σ a) % d)
  | .u64Bin op a b =>
    let x := FiniteField.val (eval σ a)
    let y := FiniteField.val (eval σ b)
    FiniteField.fromNat <| match op with
      | .bitAnd => x &&& y
      | .bitOr => x ||| y
      | .bitXor => x ^^^ y
      | .shl => x <<< y
      | .shr => x >>> y

/-! ## Reading the Clean circuit

Deliberately *not* `Witness.ofFExpr`. That is the emitter's recognizer; using it
here would make the comparison a check of the emitter against itself. These are a
separate traversal, and `eval_ofWitgen` below proves they mean what Clean means —
which is the property `ofFExpr` has only by inspection. -/

/-- Read an embedded circuit expression. Total. -/
def ofExpression : Expression F → WExpr
  | .var v => .cell v.index
  | .const c => .const (FiniteField.val c)
  | .add a b => .add (ofExpression a) (ofExpression b)
  | .mul a b => .mul (ofExpression a) (ofExpression b)

/-- Rewrite every variable reference through `f`. -/
def rename (f : Nat → Nat) : WExpr → WExpr
  | .cell i => .cell (f i)
  | .const n => .const n
  | .add a b => .add (rename f a) (rename f b)
  | .mul a b => .mul (rename f a) (rename f b)
  | .uintdiv a d => .uintdiv (rename f a) d
  | .umod a d => .umod (rename f a) d
  | .u64Bin op a b => .u64Bin op (rename f a) (rename f b)

/-- Evaluation depends on the assignment only pointwise. -/
theorem eval_congr {σ τ : Nat → F} (h : ∀ i, σ i = τ i) (w : WExpr) :
    eval σ w = eval τ w := by
  induction w with
  | cell i => exact h i
  | const n => rfl
  | add a b iha ihb => simp [eval, iha, ihb]
  | mul a b iha ihb => simp [eval, iha, ihb]
  | uintdiv a d ih => simp [eval, ih]
  | umod a d ih => simp [eval, ih]
  | u64Bin op a b iha ihb => simp [eval, iha, ihb]

/-- Renaming commutes with evaluation.

With `eval_congr`, this is what makes canonicalising copies in
`WitnessSet.ofSource` meaning-preserving: `canon` sends a variable only to one
the witness program defines it *equal* to, so `σ ∘ canon` and `σ` agree on every
assignment the circuit can produce, and the renamed reading evaluates to the
same field element as the original. -/
theorem eval_rename (σ : Nat → F) (f : Nat → Nat) (w : WExpr) :
    eval σ (w.rename f) = eval (σ ∘ f) w := by
  induction w with
  | cell i => rfl
  | const n => rfl
  | add a b iha ihb => simp [eval, rename, iha, ihb]
  | mul a b iha ihb => simp [eval, rename, iha, ihb]
  | uintdiv a d ih => simp [eval, rename, ih]
  | umod a d ih => simp [eval, rename, ih]
  | u64Bin op a b iha ihb => simp [eval, rename, iha, ihb]

mutual

  /-- Read a field-sorted witness expression, or fail on anything outside the
  Stage-1 subset. -/
  def ofWitgen : Witgen.FExpr F → Option WExpr
    | .expr e => some (ofExpression e)
    | .const c => some (.const (FiniteField.val c))
    | .add a b => (ofWitgen a).bind fun wa => (ofWitgen b).map (WExpr.add wa)
    | .mul a b => (ofWitgen a).bind fun wa => (ofWitgen b).map (WExpr.mul wa)
    | .ofU64 e => ofU64 e
    | _ => none

  /-- Independently read a u64 source expression under D033's proved bound.
  This traverses the Clean source directly; it does not call the emitter's
  `FieldExpr.ofU64`. -/
  private def ofU64 (e : Witgen.U64Expr F) : Option WExpr := do
    let bound ← LLZK.U64Expr.upperBound (FiniteField.size F) e
    guard (bound ≤ FiniteField.size F)
    match e with
    | .const n => some (.const n.toNat)
    | .val x => ofWitgen x
    | .add a b => return .add (← ofU64 a) (← ofU64 b)
    | .mul a b => return .mul (← ofU64 a) (← ofU64 b)
    | .div a (.const d) => do
      guard (d != 0 ∧ d.toNat < FiniteField.size F)
      return .uintdiv (← ofU64 a) d.toNat
    | .mod a (.const d) => do
      guard (d != 0 ∧ d.toNat < FiniteField.size F)
      return .umod (← ofU64 a) d.toNat
    | .land a b => return .u64Bin .bitAnd (← ofU64 a) (← ofU64 b)
    | .lor a b => return .u64Bin .bitOr (← ofU64 a) (← ofU64 b)
    | .lxor a b => return .u64Bin .bitXor (← ofU64 a) (← ofU64 b)
    | .shiftL a (.const amount) => do
      guard (amount.toNat < FiniteField.size F)
      return .u64Bin .shl (← ofU64 a) (.const amount.toNat)
    | .shiftR a (.const amount) => do
      guard (amount.toNat < FiniteField.size F)
      return .u64Bin .shr (← ofU64 a) (.const amount.toNat)
    | _ => none

end

/-- The structural layer of `ofU64`, named separately so the semantic proof can
peel off the bound check without unfolding recursive calls. -/
private def ofU64Body (e : Witgen.U64Expr F) : Option WExpr :=
  match e with
  | .const n => some (.const n.toNat)
  | .val x => ofWitgen x
  | .add a b => return .add (← ofU64 a) (← ofU64 b)
  | .mul a b => return .mul (← ofU64 a) (← ofU64 b)
  | .div a (.const d) => do
    guard (d != 0 ∧ d.toNat < FiniteField.size F)
    return .uintdiv (← ofU64 a) d.toNat
  | .mod a (.const d) => do
    guard (d != 0 ∧ d.toNat < FiniteField.size F)
    return .umod (← ofU64 a) d.toNat
  | .land a b => return .u64Bin .bitAnd (← ofU64 a) (← ofU64 b)
  | .lor a b => return .u64Bin .bitOr (← ofU64 a) (← ofU64 b)
  | .lxor a b => return .u64Bin .bitXor (← ofU64 a) (← ofU64 b)
  | .shiftL a (.const amount) => do
    guard (amount.toNat < FiniteField.size F)
    return .u64Bin .shl (← ofU64 a) (.const amount.toNat)
  | .shiftR a (.const amount) => do
    guard (amount.toNat < FiniteField.size F)
    return .u64Bin .shr (← ofU64 a) (.const amount.toNat)
  | _ => none

private theorem ofU64_eq_bound_body (e : Witgen.U64Expr F) :
    ofU64 e = (do
      let bound ← LLZK.U64Expr.upperBound (FiniteField.size F) e
      guard (bound ≤ FiniteField.size F)
      ofU64Body e) := by
  unfold ofU64
  cases e <;> rfl

private theorem body_of_ofU64 {e : Witgen.U64Expr F} {w : WExpr}
    (h : ofU64 e = some w) : ofU64Body e = some w := by
  rw [ofU64_eq_bound_body] at h
  cases hb : LLZK.U64Expr.upperBound (FiniteField.size F) e with
  | none => simp [hb] at h
  | some bound =>
    have hle : bound ≤ FiniteField.size F := by
      by_contra hn
      simp [hb, hn] at h
    simp [hb, hle] at h
    exact h

/-! ## The readings mean what Clean means -/

/-- Reading an embedded circuit expression preserves its meaning. -/
theorem eval_ofExpression (σ : Nat → F) (env : Environment F) (hσ : ∀ i, σ i = env.get i)
    (e : Expression F) : eval σ (ofExpression e) = e.eval env := by
  induction e with
  | var v => simp [eval, ofExpression, Expression.eval, hσ]
  | const c => simp [eval, ofExpression, Expression.eval, FiniteField.fromNat_val]
  | add a b iha ihb => simp [eval, ofExpression, Expression.eval, iha, ihb]
  | mul a b iha ihb => simp [eval, ofExpression, Expression.eval, iha, ihb]

/-- A successful D033 analysis really is an exclusive upper bound on the Clean
u64 value. This theorem is independent of LLZK; it closes the source-side fact
that recognition relies on before any felt operation is emitted. -/
theorem eval_lt_upperBound (ctx : Witgen.Ctx F) (prime : Nat)
    (hprime : FiniteField.size F = prime) :
    ∀ (e : Witgen.U64Expr F) (bound : Nat),
      LLZK.U64Expr.upperBound prime e = some bound → (e.eval ctx).toNat < bound := by
  intro e
  induction e using LLZK.U64Expr.upperBound.induct (prime := prime) with
  | case1 n =>
    intro bound h
    cases h
    simp [Witgen.U64Expr.eval]
  | case2 x hwidth =>
    intro bound h
    rw [LLZK.U64Expr.upperBound, if_pos hwidth] at h
    cases h
    have hv : FiniteField.val (x.eval ctx) < prime := by
      rw [← hprime]
      exact FiniteField.val_lt (x.eval ctx)
    have hv64 : FiniteField.val (x.eval ctx) < 2 ^ 64 := lt_of_lt_of_le hv hwidth.2
    simp [Witgen.U64Expr.eval, UInt64.toNat_ofNat', hv]
  | case3 x hwidth =>
    intro bound h
    rw [LLZK.U64Expr.upperBound, if_neg hwidth] at h
    contradiction
  | case4 a b iha ihb =>
    intro bound h
    cases hba : LLZK.U64Expr.upperBound prime a with
    | none => simp [LLZK.U64Expr.upperBound, hba] at h
    | some ba =>
      cases hbb : LLZK.U64Expr.upperBound prime b with
      | none => simp [LLZK.U64Expr.upperBound, hba, hbb] at h
      | some bb =>
        by_cases hmax : ba + bb ≤ LLZK.U64Expr.modulus
        · simp [LLZK.U64Expr.upperBound, hba, hbb, hmax] at h
          subst bound
          have ha := iha ba hba
          have hb := ihb bb hbb
          have hsum : (a.eval ctx).toNat + (b.eval ctx).toNat < ba + bb := by omega
          change ba + bb ≤ 2 ^ 64 at hmax
          rw [Witgen.U64Expr.eval, UInt64.toNat_add,
            Nat.mod_eq_of_lt (lt_of_lt_of_le hsum hmax)]
          exact hsum
        · simp [LLZK.U64Expr.upperBound, hba, hbb, hmax] at h
  | case5 a b iha ihb =>
    intro bound h
    cases hba : LLZK.U64Expr.upperBound prime a with
    | none => simp [LLZK.U64Expr.upperBound, hba] at h
    | some ba =>
      cases hbb : LLZK.U64Expr.upperBound prime b with
      | none => simp [LLZK.U64Expr.upperBound, hba, hbb] at h
      | some bb =>
        by_cases hmax : ba * bb ≤ LLZK.U64Expr.modulus
        · simp [LLZK.U64Expr.upperBound, hba, hbb, hmax] at h
          subst bound
          have ha := iha ba hba
          have hb := ihb bb hbb
          have hmul : (a.eval ctx).toNat * (b.eval ctx).toNat < ba * bb := by nlinarith
          change ba * bb ≤ 2 ^ 64 at hmax
          rw [Witgen.U64Expr.eval, UInt64.toNat_mul,
            Nat.mod_eq_of_lt (lt_of_lt_of_le hmul hmax)]
          exact hmul
        · simp [LLZK.U64Expr.upperBound, hba, hbb, hmax] at h
  | case6 a => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case7 a d hd iha =>
    intro bound h
    rw [LLZK.U64Expr.upperBound, if_neg hd] at h
    have ha := iha bound h
    simp only [Witgen.U64Expr.eval, UInt64.toNat_div]
    exact lt_of_le_of_lt (Nat.div_le_self _ _) ha
  | case8 a => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case9 a d hd iha =>
    intro bound h
    rw [LLZK.U64Expr.upperBound, if_neg hd] at h
    have ha := iha bound h
    simp only [Witgen.U64Expr.eval, UInt64.toNat_mod]
    exact lt_of_le_of_lt (Nat.mod_le _ _) ha
  | case10 a b iha ihb =>
    intro bound h
    cases hba : LLZK.U64Expr.upperBound prime a with
    | none => simp [LLZK.U64Expr.upperBound, hba] at h
    | some ba =>
      cases hbb : LLZK.U64Expr.upperBound prime b with
      | none => simp [LLZK.U64Expr.upperBound, hba, hbb] at h
      | some bb =>
        simp [LLZK.U64Expr.upperBound, hba, hbb] at h
        subst bound
        have ha := iha ba hba
        exact lt_of_le_of_lt Nat.and_le_left ha
  | case11 a b iha ihb =>
    intro bound h
    cases hba : LLZK.U64Expr.upperBound prime a with
    | none => simp [LLZK.U64Expr.upperBound, hba] at h
    | some ba =>
      cases hbb : LLZK.U64Expr.upperBound prime b with
      | none => simp [LLZK.U64Expr.upperBound, hba, hbb] at h
      | some bb =>
        simp [LLZK.U64Expr.upperBound, hba, hbb] at h
        subst bound
        exact UInt64.toNat_lt_size _
  | case12 a b iha ihb =>
    intro bound h
    cases hba : LLZK.U64Expr.upperBound prime a with
    | none => simp [LLZK.U64Expr.upperBound, hba] at h
    | some ba =>
      cases hbb : LLZK.U64Expr.upperBound prime b with
      | none => simp [LLZK.U64Expr.upperBound, hba, hbb] at h
      | some bb =>
        simp [LLZK.U64Expr.upperBound, hba, hbb] at h
        subst bound
        exact UInt64.toNat_lt_size _
  | case13 a amount hamount iha =>
    intro bound h
    cases hba : LLZK.U64Expr.upperBound prime a with
    | none => simp [LLZK.U64Expr.upperBound, hamount, hba] at h
    | some ba =>
      by_cases hmax : ba * 2 ^ amount.toNat ≤ LLZK.U64Expr.modulus
      · simp [LLZK.U64Expr.upperBound, hamount, hba, hmax] at h
        subst bound
        have ha := iha ba hba
        have hmul : (a.eval ctx).toNat * 2 ^ amount.toNat < ba * 2 ^ amount.toNat := by
          exact Nat.mul_lt_mul_of_pos_right ha (Nat.two_pow_pos _)
        change ba * 2 ^ amount.toNat ≤ 2 ^ 64 at hmax
        simp only [Witgen.U64Expr.eval]
        rw [UInt64.toNat_shiftLeft, Nat.mod_eq_of_lt hamount, Nat.shiftLeft_eq,
          Nat.mod_eq_of_lt (lt_of_lt_of_le hmul hmax)]
        exact hmul
      · simp [LLZK.U64Expr.upperBound, hamount, hba, hmax] at h
  | case14 a amount hamount =>
    intro bound h
    simp [LLZK.U64Expr.upperBound, hamount] at h
  | case15 a amount hamount iha =>
    intro bound h
    rw [LLZK.U64Expr.upperBound, if_pos hamount] at h
    have ha := iha bound h
    simp only [Witgen.U64Expr.eval]
    rw [UInt64.toNat_shiftRight, Nat.mod_eq_of_lt hamount]
    exact lt_of_le_of_lt (Nat.shiftRight_le _ _) ha
  | case16 a amount hamount =>
    intro bound h
    simp [LLZK.U64Expr.upperBound, hamount] at h
  | case17 => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case18 i => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case19 x y hy => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case20 x y hy => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case21 x y hy => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case22 x y hy => intro bound h; simp [LLZK.U64Expr.upperBound] at h
  | case23 c t e => intro bound h; simp [LLZK.U64Expr.upperBound] at h

/-- Success of the independent source reader exposes the checked root bound. -/
private theorem upperBound_of_ofU64 {e : Witgen.U64Expr F} {w : WExpr}
    (h : ofU64 e = some w) :
    ∃ bound, LLZK.U64Expr.upperBound (FiniteField.size F) e = some bound ∧
      bound ≤ FiniteField.size F := by
  rw [ofU64_eq_bound_body] at h
  cases hb : LLZK.U64Expr.upperBound (FiniteField.size F) e with
  | none => simp [hb] at h
  | some bound =>
    by_cases hle : bound ≤ FiniteField.size F
    · exact ⟨bound, rfl, hle⟩
    · simp [hb, hle] at h

private theorem eval_lt_size_of_ofU64 (ctx : Witgen.Ctx F)
    {e : Witgen.U64Expr F} {w : WExpr} (h : ofU64 e = some w) :
    (e.eval ctx).toNat < FiniteField.size F := by
  obtain ⟨bound, hb, hbound⟩ := upperBound_of_ofU64 h
  exact lt_of_lt_of_le
    (eval_lt_upperBound ctx (FiniteField.size F) rfl e bound hb) hbound

private theorem eval_add_lt_limits (ctx : Witgen.Ctx F) {a b : Witgen.U64Expr F}
    {w : WExpr} (h : ofU64 (.add a b) = some w) :
    (a.eval ctx).toNat + (b.eval ctx).toNat < FiniteField.size F ∧
      (a.eval ctx).toNat + (b.eval ctx).toNat < LLZK.U64Expr.modulus := by
  obtain ⟨bound, hroot, hfield⟩ := upperBound_of_ofU64 h
  cases ha : LLZK.U64Expr.upperBound (FiniteField.size F) a with
  | none => simp [LLZK.U64Expr.upperBound, ha] at hroot
  | some ba =>
    cases hb : LLZK.U64Expr.upperBound (FiniteField.size F) b with
    | none => simp [LLZK.U64Expr.upperBound, ha, hb] at hroot
    | some bb =>
      by_cases hmax : ba + bb ≤ LLZK.U64Expr.modulus
      · simp [LLZK.U64Expr.upperBound, ha, hb, hmax] at hroot
        subst bound
        have hea := eval_lt_upperBound ctx (FiniteField.size F) rfl a ba ha
        have heb := eval_lt_upperBound ctx (FiniteField.size F) rfl b bb hb
        constructor <;> omega
      · simp [LLZK.U64Expr.upperBound, ha, hb, hmax] at hroot

private theorem eval_mul_lt_limits (ctx : Witgen.Ctx F) {a b : Witgen.U64Expr F}
    {w : WExpr} (h : ofU64 (.mul a b) = some w) :
    (a.eval ctx).toNat * (b.eval ctx).toNat < FiniteField.size F ∧
      (a.eval ctx).toNat * (b.eval ctx).toNat < LLZK.U64Expr.modulus := by
  obtain ⟨bound, hroot, hfield⟩ := upperBound_of_ofU64 h
  cases ha : LLZK.U64Expr.upperBound (FiniteField.size F) a with
  | none => simp [LLZK.U64Expr.upperBound, ha] at hroot
  | some ba =>
    cases hb : LLZK.U64Expr.upperBound (FiniteField.size F) b with
    | none => simp [LLZK.U64Expr.upperBound, ha, hb] at hroot
    | some bb =>
      by_cases hmax : ba * bb ≤ LLZK.U64Expr.modulus
      · simp [LLZK.U64Expr.upperBound, ha, hb, hmax] at hroot
        subst bound
        have hea := eval_lt_upperBound ctx (FiniteField.size F) rfl a ba ha
        have heb := eval_lt_upperBound ctx (FiniteField.size F) rfl b bb hb
        constructor <;> nlinarith
      · simp [LLZK.U64Expr.upperBound, ha, hb, hmax] at hroot

private theorem eval_shiftLeft_lt_limits (ctx : Witgen.Ctx F)
    {a : Witgen.U64Expr F} {amount : UInt64} {w : WExpr}
    (h : ofU64 (.shiftL a (.const amount)) = some w) :
    (a.eval ctx).toNat * 2 ^ amount.toNat < FiniteField.size F ∧
      (a.eval ctx).toNat * 2 ^ amount.toNat < LLZK.U64Expr.modulus := by
  obtain ⟨bound, hroot, hfield⟩ := upperBound_of_ofU64 h
  by_cases hamount : amount.toNat < 64
  · cases ha : LLZK.U64Expr.upperBound (FiniteField.size F) a with
    | none => simp [LLZK.U64Expr.upperBound, hamount, ha] at hroot
    | some ba =>
      by_cases hmax : ba * 2 ^ amount.toNat ≤ LLZK.U64Expr.modulus
      · simp [LLZK.U64Expr.upperBound, hamount, ha, hmax] at hroot
        subst bound
        have hea := eval_lt_upperBound ctx (FiniteField.size F) rfl a ba ha
        have hpow : 0 < 2 ^ amount.toNat := Nat.two_pow_pos _
        constructor <;> nlinarith
      · simp [LLZK.U64Expr.upperBound, hamount, ha, hmax] at hroot
  · simp [LLZK.U64Expr.upperBound, hamount] at hroot

private theorem fromNat_add_of_lt [CanonicalRepr F] {a b : Nat}
    (ha : a < FiniteField.size F) (hb : b < FiniteField.size F)
    (hab : a + b < FiniteField.size F) :
    FiniteField.fromNat (a + b) =
      (FiniteField.fromNat a : F) + FiniteField.fromNat b := by
  apply FiniteField.val_injective
  rw [FiniteField.val_fromNat _ hab, CanonicalRepr.val_add,
    FiniteField.val_fromNat _ ha, FiniteField.val_fromNat _ hb,
    Nat.mod_eq_of_lt hab]

private theorem fromNat_mul_of_lt [CanonicalRepr F] {a b : Nat}
    (ha : a < FiniteField.size F) (hb : b < FiniteField.size F)
    (hab : a * b < FiniteField.size F) :
    FiniteField.fromNat (a * b) =
      (FiniteField.fromNat a : F) * FiniteField.fromNat b := by
  apply FiniteField.val_injective
  rw [FiniteField.val_fromNat _ hab, CanonicalRepr.val_mul,
    FiniteField.val_fromNat _ ha, FiniteField.val_fromNat _ hb,
    Nat.mod_eq_of_lt hab]

/-- **Reading a Clean witness expression preserves its meaning.**

The u64 cases carry D033's checked bounds. `CanonicalRepr` supplies exactly the
prime-field law needed for admitted u64 addition and multiplication; without it
the theorem is false for the binary fields covered by `FiniteField`. -/
theorem eval_ofWitgen [CanonicalRepr F] (ctx : Witgen.Ctx F) (σ : Nat → F)
    (hσ : ∀ i, σ i = ctx.env.get i) :
    ∀ (e : Witgen.FExpr F) (w : WExpr), ofWitgen e = some w → eval σ w = e.eval ctx := by
  intro e
  induction e using ofWitgen.induct
      (motive_2 := fun e => ∀ w, ofU64 e = some w →
        eval σ w = FiniteField.fromNat (e.eval ctx).toNat) with
  | case1 e => intro w h; cases h; exact eval_ofExpression σ _ hσ e
  | case2 c => intro w h; cases h; simp [eval, Witgen.FExpr.eval, FiniteField.fromNat_val]
  | case3 a b iha ihb =>
    intro w h
    simp only [ofWitgen, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨wa, ha, wb, hb, rfl⟩ := h
    simp [eval, Witgen.FExpr.eval, iha wa ha, ihb wb hb]
  | case4 a b iha ihb =>
    intro w h
    simp only [ofWitgen, Option.bind_eq_some_iff, Option.map_eq_some_iff] at h
    obtain ⟨wa, ha, wb, hb, rfl⟩ := h
    simp [eval, Witgen.FExpr.eval, iha wa ha, ihb wb hb]
  | case5 e ih =>
    intro w h
    exact ih w h
  | case6 t h1 h2 h3 h4 h5 =>
    intro w h
    simp [ofWitgen] at h
  | case7 t ih w h =>
    have hbody := body_of_ofU64 h
    cases t with
    | const n =>
      simp [ofU64Body] at hbody
      cases hbody
      rfl
    | val x =>
      simp [ofU64Body] at hbody
      rw [ih _ hbody]
      obtain ⟨bound, hb, hle⟩ := upperBound_of_ofU64 h
      simp only [LLZK.U64Expr.upperBound] at hb
      split at hb
      · rename_i hwidth
        cases hb
        have hv : FiniteField.val (Witgen.FExpr.eval ctx x) < 2 ^ 64 := by
          have hwidth64 := hwidth.2
          change FiniteField.size F ≤ 2 ^ 64 at hwidth64
          exact lt_of_lt_of_le (FiniteField.val_lt _) hwidth64
        rw [Witgen.U64Expr.eval, UInt64.toNat_ofNat', Nat.mod_eq_of_lt hv]
        exact (FiniteField.fromNat_val _).symm
      · contradiction
    | add a b =>
      rcases ih with ⟨iha, ihb⟩
      cases ha : ofU64 a with
      | none => simp [ofU64Body, ha] at hbody
      | some wa =>
       cases hb : ofU64 b with
       | none => simp [ofU64Body, ha, hb] at hbody
       | some wb =>
        simp [ofU64Body, ha, hb] at hbody
        subst w
        have hab := eval_add_lt_limits ctx h
        rw [Witgen.U64Expr.eval, UInt64.toNat_add]
        have hab64 := hab.2
        change (a.eval ctx).toNat + (b.eval ctx).toNat < 2 ^ 64 at hab64
        rw [Nat.mod_eq_of_lt hab64]
        rw [eval, iha wa ha, ihb wb hb,
          ← fromNat_add_of_lt (eval_lt_size_of_ofU64 ctx ha)
            (eval_lt_size_of_ofU64 ctx hb) hab.1]
    | mul a b =>
      rcases ih with ⟨iha, ihb⟩
      cases ha : ofU64 a with
      | none => simp [ofU64Body, ha] at hbody
      | some wa =>
       cases hb : ofU64 b with
       | none => simp [ofU64Body, ha, hb] at hbody
       | some wb =>
        simp [ofU64Body, ha, hb] at hbody
        subst w
        have hab := eval_mul_lt_limits ctx h
        rw [Witgen.U64Expr.eval, UInt64.toNat_mul]
        have hab64 := hab.2
        change (a.eval ctx).toNat * (b.eval ctx).toNat < 2 ^ 64 at hab64
        rw [Nat.mod_eq_of_lt hab64]
        rw [eval, iha wa ha, ihb wb hb,
          ← fromNat_mul_of_lt (eval_lt_size_of_ofU64 ctx ha)
            (eval_lt_size_of_ofU64 ctx hb) hab.1]
    | div a b =>
      cases b with
      | const d =>
        by_cases hd : d ≠ 0 ∧ d.toNat < FiniteField.size F
        · cases ha : ofU64 a with
          | none => simp [ofU64Body, hd, ha] at hbody
          | some wa =>
            simp [ofU64Body, hd, ha] at hbody
            subst w
            have hva := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx ha)
            simp [eval, Witgen.U64Expr.eval, ih wa ha, hva, UInt64.toNat_div]
        · simp [ofU64Body, hd] at hbody
      | val x => simp [ofU64Body] at hbody
      | idx => simp [ofU64Body] at hbody
      | localVar i => simp [ofU64Body] at hbody
      | add x y => simp [ofU64Body] at hbody
      | mul x y => simp [ofU64Body] at hbody
      | div x y => simp [ofU64Body] at hbody
      | mod x y => simp [ofU64Body] at hbody
      | land x y => simp [ofU64Body] at hbody
      | lor x y => simp [ofU64Body] at hbody
      | lxor x y => simp [ofU64Body] at hbody
      | shiftL x y => simp [ofU64Body] at hbody
      | shiftR x y => simp [ofU64Body] at hbody
      | ite c t e => simp [ofU64Body] at hbody
    | mod a b =>
      cases b with
      | const d =>
        by_cases hd : d ≠ 0 ∧ d.toNat < FiniteField.size F
        · cases ha : ofU64 a with
          | none => simp [ofU64Body, hd, ha] at hbody
          | some wa =>
            simp [ofU64Body, hd, ha] at hbody
            subst w
            have hva := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx ha)
            simp [eval, Witgen.U64Expr.eval, ih wa ha, hva, UInt64.toNat_mod]
        · simp [ofU64Body, hd] at hbody
      | val x => simp [ofU64Body] at hbody
      | idx => simp [ofU64Body] at hbody
      | localVar i => simp [ofU64Body] at hbody
      | add x y => simp [ofU64Body] at hbody
      | mul x y => simp [ofU64Body] at hbody
      | div x y => simp [ofU64Body] at hbody
      | mod x y => simp [ofU64Body] at hbody
      | land x y => simp [ofU64Body] at hbody
      | lor x y => simp [ofU64Body] at hbody
      | lxor x y => simp [ofU64Body] at hbody
      | shiftL x y => simp [ofU64Body] at hbody
      | shiftR x y => simp [ofU64Body] at hbody
      | ite c t e => simp [ofU64Body] at hbody
    | land a b =>
      rcases ih with ⟨iha, ihb⟩
      cases ha : ofU64 a with
      | none => simp [ofU64Body, ha] at hbody
      | some wa =>
       cases hb : ofU64 b with
       | none => simp [ofU64Body, ha, hb] at hbody
       | some wb =>
        simp [ofU64Body, ha, hb] at hbody
        subst w
        have hva := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx ha)
        have hvb := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx hb)
        simp [eval, Witgen.U64Expr.eval, iha wa ha, ihb wb hb, hva, hvb]
    | lor a b =>
      rcases ih with ⟨iha, ihb⟩
      cases ha : ofU64 a with
      | none => simp [ofU64Body, ha] at hbody
      | some wa =>
       cases hb : ofU64 b with
       | none => simp [ofU64Body, ha, hb] at hbody
       | some wb =>
        simp [ofU64Body, ha, hb] at hbody
        subst w
        have hva := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx ha)
        have hvb := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx hb)
        simp [eval, Witgen.U64Expr.eval, iha wa ha, ihb wb hb, hva, hvb]
    | lxor a b =>
      rcases ih with ⟨iha, ihb⟩
      cases ha : ofU64 a with
      | none => simp [ofU64Body, ha] at hbody
      | some wa =>
       cases hb : ofU64 b with
       | none => simp [ofU64Body, ha, hb] at hbody
       | some wb =>
        simp [ofU64Body, ha, hb] at hbody
        subst w
        have hva := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx ha)
        have hvb := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx hb)
        simp [eval, Witgen.U64Expr.eval, iha wa ha, ihb wb hb, hva, hvb]
    | shiftL a b =>
      cases b with
      | const amount =>
        by_cases hamountField : amount.toNat < FiniteField.size F
        · cases ha : ofU64 a with
          | none => simp [ofU64Body, hamountField, ha] at hbody
          | some wa =>
            simp [ofU64Body, hamountField, ha] at hbody
            subst w
            have hamount : amount.toNat < 64 := by
              obtain ⟨bound, hroot, hfield⟩ := upperBound_of_ofU64 h
              simp only [LLZK.U64Expr.upperBound] at hroot
              split at hroot
              · assumption
              · contradiction
            have hva := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx ha)
            have hvamount := FiniteField.val_fromNat (F := F) _ hamountField
            have hlimits := eval_shiftLeft_lt_limits ctx h
            have hshift64 := hlimits.2
            change
              (Witgen.U64Expr.eval ctx a).toNat * 2 ^ amount.toNat <
                18446744073709551616 at hshift64
            simp [eval, Witgen.U64Expr.eval, ih wa ha, hva, hvamount,
              UInt64.toNat_shiftLeft, Nat.mod_eq_of_lt hamount, Nat.shiftLeft_eq,
              Nat.mod_eq_of_lt hshift64]
        · simp [ofU64Body, hamountField] at hbody
      | val x => simp [ofU64Body] at hbody
      | idx => simp [ofU64Body] at hbody
      | localVar i => simp [ofU64Body] at hbody
      | add x y => simp [ofU64Body] at hbody
      | mul x y => simp [ofU64Body] at hbody
      | div x y => simp [ofU64Body] at hbody
      | mod x y => simp [ofU64Body] at hbody
      | land x y => simp [ofU64Body] at hbody
      | lor x y => simp [ofU64Body] at hbody
      | lxor x y => simp [ofU64Body] at hbody
      | shiftL x y => simp [ofU64Body] at hbody
      | shiftR x y => simp [ofU64Body] at hbody
      | ite c t e => simp [ofU64Body] at hbody
    | shiftR a b =>
      cases b with
      | const amount =>
        by_cases hamountField : amount.toNat < FiniteField.size F
        · cases ha : ofU64 a with
          | none => simp [ofU64Body, hamountField, ha] at hbody
          | some wa =>
            simp [ofU64Body, hamountField, ha] at hbody
            subst w
            have hamount : amount.toNat < 64 := by
              obtain ⟨bound, hroot, hfield⟩ := upperBound_of_ofU64 h
              simp only [LLZK.U64Expr.upperBound] at hroot
              split at hroot
              · assumption
              · contradiction
            have hva := FiniteField.val_fromNat (F := F) _ (eval_lt_size_of_ofU64 ctx ha)
            have hvamount := FiniteField.val_fromNat (F := F) _ hamountField
            simp [eval, Witgen.U64Expr.eval, ih wa ha, hva, hvamount,
              UInt64.toNat_shiftRight, Nat.mod_eq_of_lt hamount]
        · simp [ofU64Body, hamountField] at hbody
      | val x => simp [ofU64Body] at hbody
      | idx => simp [ofU64Body] at hbody
      | localVar i => simp [ofU64Body] at hbody
      | add x y => simp [ofU64Body] at hbody
      | mul x y => simp [ofU64Body] at hbody
      | div x y => simp [ofU64Body] at hbody
      | mod x y => simp [ofU64Body] at hbody
      | land x y => simp [ofU64Body] at hbody
      | lor x y => simp [ofU64Body] at hbody
      | lxor x y => simp [ofU64Body] at hbody
      | shiftL x y => simp [ofU64Body] at hbody
      | shiftR x y => simp [ofU64Body] at hbody
      | ite c t e => simp [ofU64Body] at hbody
    | idx => simp [ofU64Body] at hbody
    | localVar i => simp [ofU64Body] at hbody
    | ite c t e => simp [ofU64Body] at hbody

/-- One cell of the `bitsOf` source reading denotes Clean's corresponding low
bit. Unlike `U64Expr.val`, this operates on the full canonical field
representative; `hm` only makes every emitted shift-index constant canonical. -/
theorem eval_bitsOf [CanonicalRepr F] (ctx : Witgen.Ctx F) (σ : Nat → F)
    (hσ : ∀ i, σ i = ctx.env.get i) {m i : Nat} (hm : m ≤ FiniteField.size F)
    (hi : i < m) {x : Witgen.FExpr F} {w : WExpr} (hw : ofWitgen x = some w) :
    eval σ (.u64Bin .bitAnd (.u64Bin .shr w (.const i)) (.const 1)) =
      (Witgen.VExpr.eval ctx (.bitsOf (n := m) x))[i] := by
  have hiSize : i < FiniteField.size F := lt_of_lt_of_le hi hm
  have hvalI := FiniteField.val_fromNat (F := F) i hiSize
  have hx := eval_ofWitgen ctx σ hσ x w hw
  have hshift : FiniteField.val (x.eval ctx) >>> i < FiniteField.size F :=
    lt_of_le_of_lt (Nat.shiftRight_le _ _) (FiniteField.val_lt _)
  have hvalShift := FiniteField.val_fromNat (F := F) _ hshift
  simp [eval, Witgen.VExpr.eval, Vector.getElem_mapRange, hx, hvalI, hvalShift,
    FiniteField.val_one]

end WExpr

/-- What `@compute` produces: one expression per witness cell, then one per
output field element. -/
structure WitnessSet where
  /-- How many field elements the component takes. Compared, for the reason
  `ConstraintSet.inputs` gives: without it a module built for a 1-input circuit
  matched a 4-input source (R4a-4). -/
  inputs : Nat
  cells : List WExpr
  outputs : List WExpr
deriving DecidableEq, Repr

namespace WitnessSet

variable {F : Type} [FiniteField F]

/-- Read a whole witness program: `m` expressions, or nothing. -/
private def ofProgram {m : Nat} : Witgen.WitgenIR F m → Option (List WExpr)
  | .ir [] (.lit es) => es.toList.mapM WExpr.ofWitgen
  | .ir [] (.bitsOf x) => do
      guard (m ≤ FiniteField.size F)
      let value ← WExpr.ofWitgen x
      return (List.range m).map fun i =>
        .u64Bin .bitAnd (.u64Bin .shr value (.const i)) (.const 1)
  | _ => none

/-! ### Canonicalising copies

A witness cell whose program is a bare variable — `witness x`, returning the
input unchanged — is a *copy*: circuit variable `inputSize + k` and the variable
it copies denote the same field element, always. The emitted module cannot tell
them apart, because `FieldExpr.lower` returns the existing SSA value rather than
emitting anything, so `struct.writem @w{k} = %v` writes the very value that
already stood for the original.

This is not a choice the comparison gets to make. `ofModule` reads the module and
nothing else, and `witness x; return x` and `witness x; return that cell` emit
*byte-identical* modules — the distinction is simply not present in the artifact.
So any check that accepts one must accept the other, and both sides rewrite every
copy to the variable it copies.

Accepting both is sound because the module is a correct lowering of both: a copy
cell is *defined* to hold the value it copies, so the two variables denote the
same field element under every assignment the witness generator can produce.
`eval_rename` and `eval_congr` above are the two halves of that argument. The
`CopyCanon.step_preserves` theorem below supplies the remaining premise: `canon`
sends a variable only to one the program defines it equal to.

R5c found the alternative the hard way: with the reader alone rebinding,
`witness x; y === x; return x` — a proved `FormalCircuit` whose emitted module is
correct — was refused and told to file a backend bug.

Only *bare* copies collapse. A cell computing `x + 0` is a fresh value with its
own SSA statement, and stays distinct. -/

namespace CopyCanon

/-- Canonicalise one witness expression and extend the representative map.

A bare copy maps the new circuit variable to the representative it copies;
every other expression maps the new variable to itself. Returning the renamed
expression as well keeps `ofSource`'s comparison output and the map update tied
to one computation. -/
def step (next : Nat) (canon : Nat → Nat) (w : WExpr) : (Nat → Nat) × WExpr :=
  let renamed := w.rename canon
  let representative := match renamed with | .cell j => j | _ => next
  (fun i => if i = next then representative else canon i, renamed)

/-- **The copy-canonicalisation invariant.**

If every existing representative denotes the variable it replaces, and the new
witness cell denotes its unrenamed program, then one `step` preserves that fact
for every variable. Together with `WExpr.eval_rename`, this is the premise that
used to be checked only by inspection in the three mutable lines of `ofSource`.
-/
theorem step_preserves (σ : Nat → F) (next : Nat) (canon : Nat → Nat) (w : WExpr)
    (hcanon : ∀ i, σ (canon i) = σ i)
    (hcell : σ next = WExpr.eval σ w) :
    ∀ i, σ ((step next canon w).1 i) = σ i := by
  intro i
  by_cases hi : i = next
  · subst i
    have hrename : WExpr.eval σ (w.rename canon) = WExpr.eval σ w := by
      rw [WExpr.eval_rename]
      exact WExpr.eval_congr hcanon w
    simp only [step, ↓reduceIte]
    split
    · rename_i j hcopy
      have hj : σ j = WExpr.eval σ w := by
        calc
          σ j = WExpr.eval σ (.cell j) := rfl
          _ = WExpr.eval σ (w.rename canon) :=
            congrArg (WExpr.eval σ) hcopy.symm
          _ = WExpr.eval σ w := hrename
      exact hj.trans hcell.symm
    · exact rfl
  · simp [step, hi, hcanon]

/-- Canonicalise a consecutive list of witness programs. -/
def run (next : Nat) (canon : Nat → Nat) :
    List WExpr → (Nat → Nat) × List WExpr
  | [] => (canon, [])
  | w :: ws =>
      let (nextCanon, renamed) := step next canon w
      let (finalCanon, rest) := run (next + 1) nextCanon ws
      (finalCanon, renamed :: rest)

/-- The sequential witness-cell equations needed by `run_preserves`. -/
def ProgramsHold (σ : Nat → F) (next : Nat) : List WExpr → Prop
  | [] => True
  | w :: ws =>
      σ next = WExpr.eval σ w ∧ ProgramsHold σ (next + 1) ws

/-- Canonicalising a whole witness-program list preserves every variable's
value. This is the induction from the identity map through all applications of
`step_preserves`, so `ofSource` does not rely on an inspected mutable loop. -/
theorem run_preserves (σ : Nat → F) (next : Nat) (canon : Nat → Nat)
    (raw : List WExpr) (hcanon : ∀ i, σ (canon i) = σ i)
    (hraw : ProgramsHold σ next raw) :
    ∀ i, σ ((run next canon raw).1 i) = σ i := by
  induction raw generalizing next canon with
  | nil => simpa [run] using hcanon
  | cons w ws ih =>
      rcases hraw with ⟨hcell, hrest⟩
      have hstep := step_preserves σ next canon w hcanon hcell
      simpa only [run] using
        ih (next := next + 1) (canon := (step next canon w).1) hstep hrest

end CopyCanon

/-- Read the Clean circuit's witness programs and outputs. -/
def ofSource (src : Source F) : Option WitnessSet := do
  let mut raw : List WExpr := []
  for op in src.operations do
    if let .witness _ program := op then
      raw := raw ++ (← ofProgram program)
  -- `canon` sends each circuit variable to the one it is a copy of, or to
  -- itself. `run` builds it in order, so references are already resolved, and
  -- `run_preserves` proves the resulting map preserves every variable's value.
  let (canon, cells) := CopyCanon.run src.inputSize id raw
  return { inputs := src.inputSize, cells := cells,
           outputs := src.outputs.toList.map fun e =>
             (WExpr.ofExpression e).rename canon }

/-! ## Reading the emitted `@compute`

`@compute`'s parameters are the inputs, with no `%self`; `struct.new` defines
`%self` as the first statement. A write to `@w{k}` records the cell's expression
and, in the ordinary case, rebinds the written SSA value to `cell (inputSize +
k)`: every later use of it denotes that cell, which is how the Clean side names
it. Without the rebinding the emitted side would inline earlier cells and the two
would never match.

The exception is a cell that is a bare copy — see "Canonicalising copies" above.
There the written value is one the body did not compute, and rebinding it would
rename the original for the rest of `@compute`. Because `FieldExpr.lower` returns
an existing value only in its `.var` case, and every other case emits a statement
whose slot is a `const`/`add`/`mul`/non-native operation, *the slot already holding a
bare `cell` is exactly the copy case*. That is the test used below. -/

/-- What an SSA name in `@compute` can hold. -/
private inductive Slot where
  | expr (w : WExpr)
  /-- `%self`, the value `struct.new` produced. -/
  | self

private structure Reader where
  slots : Array Slot
  cells : List WExpr
  outputs : List WExpr

private def Reader.expr (r : Reader) (v : Value) : Option WExpr :=
  match r.slots[v.index]? with
  | some (.expr w) => some w
  | _ => none

private def Reader.define (r : Reader) (v : Value) (s : Slot) : Option Reader :=
  if v.index = r.slots.size then some { r with slots := r.slots.push s } else none

/-- Rebind an already-defined slot, which only a member write does. -/
private def Reader.rebind (r : Reader) (v : Value) (w : WExpr) : Option Reader :=
  if h : v.index < r.slots.size then some { r with slots := r.slots.set v.index (.expr w) h }
  else none

/-- Interpret one statement of `@compute`.

Every type is checked against `fieldTy` (A4, `GAPS.md` §6): before that neither
half of G9 read a `Ty`, so a module emitted entirely in the wrong field passed
both, and the only thing that caught it lived in `Analyze`. -/
private def step (fieldTy : Ty) (inputSize : Nat) (r : Reader) : Stmt → Option Reader
  | .structNew dst => r.define dst .self
  | .feltConst dst value ty => do
    guard (ty = fieldTy)
    r.define dst (.expr (.const value))
  | .feltBin dst op lhs rhs ty => do
    guard (ty = fieldTy)
    let a ← r.expr lhs
    let b ← r.expr rhs
    match op with
    | .add => r.define dst (.expr (.add a b))
    | .mul => r.define dst (.expr (.mul a b))
    -- The divisor must be a literal, which is what `FieldExpr.lower` emits and
    -- what D011's side conditions are checked against.
    | .uintdiv => match b with
      | .const d => r.define dst (.expr (.uintdiv a d))
      | _ => none
    | .umod => match b with
      | .const d => r.define dst (.expr (.umod a d))
      | _ => none
    | .bitAnd => r.define dst (.expr (.u64Bin .bitAnd a b))
    | .bitOr => r.define dst (.expr (.u64Bin .bitOr a b))
    | .bitXor => r.define dst (.expr (.u64Bin .bitXor a b))
    | .shl => r.define dst (.expr (.u64Bin .shl a b))
    | .shr => r.define dst (.expr (.u64Bin .shr a b))
  | .writeMember self member value memberTy => do
    guard (memberTy = fieldTy)
    let .self ← r.slots[self.index]? | none
    let w ← r.expr value
    if member = witnessMember r.cells.length then
      let r ← if w matches .cell _ then some r
              else r.rebind value (.cell (inputSize + r.cells.length))
      return { r with cells := r.cells ++ [w] }
    else if member = outputMember r.outputs.length then
      return { r with outputs := r.outputs ++ [w] }
    else none
  -- `struct.readm`, `global.read` and the two constraint forms belong to
  -- `@constrain`. Reaching one here means the module is not the shape this
  -- reader models.
  | .readMember .. | .globalRead .. | .arrayNew .. | .constrainEq .. | .constrainIn .. => none

/-- Read the emitted module's `@compute`.

The input count comes from the parameter list, and the cell and output counts
from the order the writes appear in. The final check requires those counts to
match the exact ordered `w{k}` signal / `out{j}` public member layout, so a
module whose names, order, types, or visibility disagree with Clean's is a
mismatch rather than a blind spot shared by both sides. -/
def ofModule (fieldTy : Ty) (m : Module) : Option WitnessSet := do
  let params := m.root.compute.params
  guard (params.zipIdx.all fun (p, i) => p.value.index = i)
  guard (params.all fun p => p.ty = fieldTy)
  let mut reader : Reader :=
    { slots := (Array.range params.size).map fun i => Slot.expr (.cell i)
      cells := [], outputs := [] }
  for stmt in m.root.compute.body do
    let some next := step fieldTy params.size reader stmt | none
    reader := next
  guard (memberLayout fieldTy reader.cells.length reader.outputs.length m.root.members)
  return { inputs := params.size, cells := reader.cells, outputs := reader.outputs }

/-- Whether the emitted `@compute` computes the circuit's witnesses and outputs.

Order matters here, unlike the constraint side: cell `k` is circuit variable
`inputSize + k`, so a permutation would be a different circuit. -/
def agree (fieldTy : Ty) (src : Source F) (m : Module) : Bool :=
  match ofModule fieldTy m, ofSource src with
  | some emitted, some clean => emitted == clean
  | _, _ => false

end WitnessSet
end LLZK

/-! ## The verified entry points

Both halves of G9 are preconditions of emission (D018): `compileSource'` checks
`@constrain` against the circuit's constraints, and the step below checks
`@compute` against its witness programs. `compile` and `emit` are the only public
ways to obtain a module, and they go through both — so there is no path from a
Clean circuit to LLZK text that has not been compared against the circuit on
both sides.
-/

namespace LLZK

variable {F : Type} [FiniteField F] [DecidableEq F]

/-- What the emitter reports when its own `@compute` fails the comparison.
Reaching this is a bug in the lowering, not in the circuit. -/
private def witnessMismatch : Diagnostic where
  context := "witness"
  message := "the emitted @compute does not compute the circuit's witnesses (gate G9, witness \
              side). This is a defect in the backend, not in the circuit: please report it with \
              the circuit that triggered it. See Clean/Backend/LLZK/WitnessCheck.lean"

/-- Check a module against the circuit it claims to be — **both** halves of G9 —
and refuse it if it is not.

Factored out of `compileSourceVerified` so that the *refusal* is reachable from a
test: without a function taking the module as an argument, the error branch would
be dead code and "the check refuses a wrong module" would be an untested claim
about the one path that matters. `Test/WitnessCheck.lean` calls it with one
circuit's module and another circuit's source.

Two things this docstring used to get wrong, both found by R5c.

It said *"nothing the emitter produces can fail this"*. Something did: a bare
copy of a variable, which the witness reader misread. That claim is also what
justified never running the branch against real emitter output. The cause is
fixed — see "Canonicalising copies" — but the claim is not reinstated, because
the same sentence is what stopped anyone looking.

And it checked only the witness half while promising to refuse any module that
is not the circuit, which is exactly R2's empty-`@constrain` attack. It runs both
halves now. `compileSourceVerified` reaches it through `compileSource'`, which
has already checked the constraint half, so that half runs twice on the compile
path; it is a pure comparison of two normal forms, and paying for it is better
than a public function that means less than its name. -/
def verify [CanonicalRepr F] (cfg : CertifiedConfig F) (src : Source F) (m : Module) :
    Except (Array Diagnostic) Module :=
  if !ConstraintSet.agree cfg.toConfig src m then .error #[ConstraintSet.mismatch]
  else if !WitnessSet.agree (Ty.felt cfg.field.name) src m then .error #[witnessMismatch]
  else .ok m

/-- Compile a flattened circuit and verify **both** halves of G9 before returning
it. -/
def compileSourceVerified [CanonicalRepr F] (cfg : CertifiedConfig F) (src : Source F) :
    Except (Array Diagnostic) Module :=
  match ConstraintSet.compileSource' cfg.toConfig src with
  | .error diagnostics => .error diagnostics
  | .ok m => verify cfg src m

/-- **Every module this backend emits computes the circuit's witnesses.** -/
theorem witnessAgree_of_compileSourceVerified [CanonicalRepr F] {cfg : CertifiedConfig F}
    {src : Source F} {m : Module}
    (h : compileSourceVerified cfg src = .ok m) :
    WitnessSet.agree (Ty.felt cfg.field.name) src m = true := by
  unfold compileSourceVerified verify at h
  split at h
  · exact absurd h (by simp)
  · split at h
    · exact absurd h (by simp)
    · split at h
      · exact absurd h (by simp)
      · rename_i hw
        simp only [Except.ok.injEq] at h
        subst h
        simpa using hw

/-- **…and carries its constraint system.** The other half, lifted through the
same entry point. -/
theorem constraintsAgree_of_compileSourceVerified [CanonicalRepr F] {cfg : CertifiedConfig F}
    {src : Source F} {m : Module}
    (h : compileSourceVerified cfg src = .ok m) :
    ConstraintSet.agree cfg.toConfig src m = true := by
  unfold compileSourceVerified verify at h
  split at h
  · exact absurd h (by simp)
  · rename_i m' hc
    split at h
    · exact absurd h (by simp)
    · split at h
      · exact absurd h (by simp)
      · simp only [Except.ok.injEq] at h
        exact h ▸ ConstraintSet.agree_of_compileSource' hc

/-- Compile a circuit to an LLZK module, or report every reason it cannot be.

Verified on both sides — see the two theorems above. There is no name to pass:
the component is always `@Main` (D015).

The configuration is a `CertifiedConfig`, so a lookup table cannot reach this
function without the proof that its rows are the Clean table's (S24, closing
R5's X1). What that is *not* is in `Certificate.lean` and `GAPS.md` item 1: the
caller still picks both sides of `Certifies`, because `Table.toRaw` has already
erased which `Table` a lookup names. -/
def compile {C : Type} [CanonicalRepr F] [Compilable C F] (cfg : CertifiedConfig F) (c : C) :
    Except (Array Diagnostic) Module :=
  compileSourceVerified cfg (Compilable.source (F := F) c)

/-- Emit a circuit as textual LLZK, or as the diagnostics explaining why not.

The interactive form: `#eval IO.print (LLZK.emit cfg circuit)`. The artifact form
is `Clean/Backend/LLZK/EmitMain.lean`. -/
def emit {C : Type} [CanonicalRepr F] [Compilable C F] (cfg : CertifiedConfig F) (c : C) :
    String :=
  renderResult (compile cfg c)

/-- The same, for a circuit already reduced to a `Source`. -/
def emitSource [CanonicalRepr F] (cfg : CertifiedConfig F) (src : Source F) : String :=
  renderResult (compileSourceVerified cfg src)

end LLZK
