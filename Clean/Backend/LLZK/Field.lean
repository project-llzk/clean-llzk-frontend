import Clean.Utils.FiniteField

/-!
# The field law D011 needs and `FiniteField` does not have

R2-05: D011 argues that `FiniteField.val x` "is the canonical representative in
`[0, p)`, which is exactly the operand interpretation LLZK's `umod`/`uintdiv`
use". `FiniteField` does not say that. Its laws are `val_lt`, `val_injective`,
`val_fromNat`, `val_zero` and `val_one`, and they are satisfied by maps that are
*not* the ring representative — the class abstracts over binary fields too, where
`val` reads digits as polynomial coefficients. An injective `F → [0, size)`
fixing `0` and `1` is a bijection, and a bijection can permute the elements that
are neither.

`Analyze.checkField` pins `FiniteField.size F` and nothing more. Size `p` forces
`F ≅ 𝔽_p`, but it does not force *this* `val` to be that isomorphism. So the
translation had a side condition that was nowhere stated, and gate G7 could not
detect its violation because `Differential.witness` goes through the same
`val`/`fromNat`.

`CanonicalRepr` is that side condition, as a class. The backend's entry points
require it, so a field whose `val` is not the ring representative is a
*type error* rather than silently wrong arithmetic — the same fail-closed
treatment D010 gives a wrong prime.

## What this does and does not settle

It settles the Clean side: `val` is now known to be the canonical representative,
and `val_natCast` below derives that from the two laws. What remains is the LLZK
side — that `!felt.type<"babybear">` is `ZMod 2013265921` and that `felt.umod`
reads its operands through `ZMod.val`. That is a statement about LLZK, not about
Lean, and it belongs to D017's reading of the emitted IR.

The point is that these are now two separate, stated things, rather than one
unstated thing spanning both.
-/

namespace LLZK

/-- A `FiniteField` whose `val` is the ring representative: the canonical
representative in `[0, size)` of a prime field.

Two laws, because they are what pin `val` down — see `val_natCast`. Both hold for
`ZMod p` by `ZMod.val_add` and `ZMod.val_mul`; neither holds for the binary-field
instances `FiniteField` also abstracts over, which is precisely why they are not
laws of `FiniteField` itself. -/
class CanonicalRepr (F : Type) [FiniteField F] : Prop where
  val_add : ∀ x y : F,
    FiniteField.val (x + y) = (FiniteField.val x + FiniteField.val y) % FiniteField.size F
  val_mul : ∀ x y : F,
    FiniteField.val (x * y) = (FiniteField.val x * FiniteField.val y) % FiniteField.size F

namespace CanonicalRepr

variable {F : Type} [FiniteField F]

/-- A field has at least two elements: `val 0 = 0`, `val 1 = 1`, and `val` lands
below `size`. -/
theorem one_lt_size : 1 < FiniteField.size F :=
  FiniteField.val_one (F := F) ▸ FiniteField.val_lt (1 : F)

variable [CanonicalRepr F]

/-- **`val` is determined**: it sends `(n : F)` to `n % size`, so it is the
canonical representative and not merely some injection into `[0, size)`.

This is the content of the class. Without `val_add` the statement is false — a
`val` that permutes two elements away from `0` and `1` satisfies every law
`FiniteField` has. -/
theorem val_natCast (n : ℕ) : FiniteField.val ((n : F)) = n % FiniteField.size F := by
  induction n with
  | zero => simpa using FiniteField.val_zero (F := F)
  | succ n ih =>
    rw [Nat.cast_succ, val_add, ih, FiniteField.val_one, Nat.mod_add_mod]

end CanonicalRepr

/-- Clean's prime fields are canonically represented: `FiniteField.val` for
`F p` *is* `ZMod.val`. -/
instance {p : ℕ} [Fact p.Prime] : CanonicalRepr (F p) where
  val_add x y := by
    have : Fact (0 < p) := ⟨Nat.pos_of_ne_zero (Nat.Prime.ne_zero Fact.out)⟩
    exact ZMod.val_add x y
  val_mul x y := by
    have : Fact (0 < p) := ⟨Nat.pos_of_ne_zero (Nat.Prime.ne_zero Fact.out)⟩
    exact ZMod.val_mul x y

end LLZK
