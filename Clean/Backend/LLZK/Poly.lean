import Clean.Utils.FiniteField

/-!
# Canonical multivariate polynomials over the circuit's cells

The common language in which a Clean constraint and an emitted LLZK constraint
can be compared. Both sides are polynomial: Clean's `Expression` has exactly
`var`, `const`, `add`, `mul`, and the emitted `@constrain` uses exactly
`felt.const`, `felt.add`, `felt.mul` and reads of parameters and members — the
non-native natural, bitwise, and shift operations are witness-only and never
appear there.

So a *syntactic* comparison of normal forms is an *exact* comparison of the two
constraint systems, which is what `Clean/Backend/LLZK/Constraints.lean` does.
Everything here exists to make that comparison mean something: every operation
comes with the theorem that it commutes with evaluation, so two polynomials equal
as data denote the same function of the cells.

The representation is deliberately naive — an association list from monomial to
coefficient. These are three-variable, degree-two polynomials; a better structure
would cost proof complexity, not buy runtime.

## Canonicity is not load-bearing, but it is real

`addTerm` keeps the list ordered so that equal polynomials get equal
representations. If that ordering were wrong, two equal polynomials could get
*different* representations and the comparison would report a spurious
mismatch — a red gate, never a green one. Nothing below relies on canonicity;
soundness rests only on the `eval` theorems, and "equal as data implies equal
denotation" is true of any representation.

It does work, though, and that is what makes the gate usable rather than merely
sound: the normal form absorbs commutativity, associativity, distributivity and
cancellation, so `x*y` and `y*x`, and `(x+y)*z` and `x*z + y*z`, compare equal.
`Test/Constraints.lean` pins that, together with the fact that distinct
polynomials stay distinct — without which the four canonicity guards would be
satisfied by a normal form that collapses everything.
-/

namespace LLZK

/-- A cell of the emitted component, as a polynomial variable.

Two constructors rather than one `Nat` because Clean's circuit variables and the
emitter's own `@out{j}` members live in different namespaces: an output member is
not a circuit variable, and one index space would let an assertion naming a high
circuit variable collide with an output cell. -/
inductive PVar where
  /-- Clean circuit variable `i`: input `i` when `i < inputSize`, otherwise
  witness cell `i - inputSize`. -/
  | circuit (i : Nat)
  /-- The emitter's `@out{j}` member (D008). -/
  | output (j : Nat)
deriving DecidableEq, Repr

/-- A total order on cells, used only to keep monomials canonical. -/
def PVar.lt : PVar → PVar → Bool
  | .circuit i, .circuit j => i < j
  | .circuit _, .output _ => true
  | .output _, .circuit _ => false
  | .output i, .output j => i < j

/-- A monomial: the cells multiplied together, ordered, with repetitions for
higher powers.

Dot notation is deliberately not used on this type anywhere: it is an `abbrev`
for `List PVar`, so `m.foo` would resolve against `List`. -/
abbrev Monomial := List PVar

namespace Monomial

/-- Insert one factor into an ordered monomial. -/
def insert (v : PVar) : Monomial → Monomial
  | [] => [v]
  | w :: m => if PVar.lt w v then w :: insert v m else v :: w :: m

/-- Multiply two monomials. Insertion rather than `sort (a ++ b)` so that
`eval_mul` is a plain structural induction with no permutation reasoning. -/
def mul : Monomial → Monomial → Monomial
  | [], b => b
  | v :: a, b => insert v (mul a b)

/-- Lexicographic order on monomials. Only used for canonicity. -/
def before : Monomial → Monomial → Bool
  | [], [] => false
  | [], _ :: _ => true
  | _ :: _, [] => false
  | x :: xs, y :: ys => if x = y then before xs ys else PVar.lt x y

variable {F : Type} [Field F]

/-- The product of the cells' values. -/
def eval (σ : PVar → F) : Monomial → F
  | [] => 1
  | v :: m => σ v * eval σ m

@[simp] theorem eval_nil (σ : PVar → F) : eval σ ([] : Monomial) = 1 := rfl

@[simp] theorem eval_cons (σ : PVar → F) (v : PVar) (m : Monomial) :
    eval σ (v :: m) = σ v * eval σ m := rfl

theorem eval_insert (σ : PVar → F) (v : PVar) (m : Monomial) :
    eval σ (insert v m) = σ v * eval σ m := by
  induction m with
  | nil => simp [insert]
  | cons w m ih =>
    by_cases h : PVar.lt w v
    · rw [insert, if_pos h, eval_cons, ih, eval_cons]; ring
    · rw [insert, if_neg h, eval_cons]

theorem eval_mul (σ : PVar → F) (a b : Monomial) :
    eval σ (mul a b) = eval σ a * eval σ b := by
  induction a with
  | nil => simp [mul]
  | cons v a ih => rw [mul, eval_insert, ih, eval_cons]; ring

end Monomial

/-- A polynomial: monomials with their coefficients.

The invariant `addTerm` maintains — ordered by monomial, no repeated monomial, no
zero coefficient — is not a subtype. It buys canonicity, and canonicity buys only
the absence of spurious mismatches; see the module docstring. -/
abbrev Poly (F : Type) := List (Monomial × F)

namespace Poly

variable {F : Type} [Field F]

def eval (σ : PVar → F) : Poly F → F
  | [] => 0
  | (m, c) :: p => c * Monomial.eval σ m + eval σ p

@[simp] theorem eval_nil (σ : PVar → F) : eval σ ([] : Poly F) = 0 := rfl

@[simp] theorem eval_cons (σ : PVar → F) (m : Monomial) (c : F) (p : Poly F) :
    eval σ ((m, c) :: p) = c * Monomial.eval σ m + eval σ p := rfl

/-- The zero polynomial. -/
def zero : Poly F := []

/-- A single cell. -/
def var (v : PVar) : Poly F := [([v], 1)]

@[simp] theorem eval_zero (σ : PVar → F) : eval σ (zero : Poly F) = 0 := rfl

@[simp] theorem eval_var (σ : PVar → F) (v : PVar) : eval σ (var v) = σ v := by
  simp [var]

variable [DecidableEq F]

/-- A constant. -/
def const (c : F) : Poly F := if c = 0 then [] else [([], c)]

@[simp] theorem eval_const (σ : PVar → F) (c : F) : eval σ (const c) = c := by
  by_cases h : c = 0 <;> simp [const, h]

/-- Add one term, combining it with an existing monomial if there is one and
dropping the result when the coefficient cancels. -/
def addTerm (m : Monomial) (c : F) : Poly F → Poly F
  | [] => if c = 0 then [] else [(m, c)]
  | (m', c') :: p =>
    if m = m' then (if c' + c = 0 then p else (m', c' + c) :: p)
    else if Monomial.before m m' then (if c = 0 then (m', c') :: p else (m, c) :: (m', c') :: p)
    else (m', c') :: addTerm m c p

theorem eval_addTerm (σ : PVar → F) (m : Monomial) (c : F) (p : Poly F) :
    eval σ (addTerm m c p) = c * Monomial.eval σ m + eval σ p := by
  induction p with
  | nil => by_cases h : c = 0 <;> simp [addTerm, h]
  | cons t p ih =>
    obtain ⟨m', c'⟩ := t
    simp only [addTerm]
    split_ifs with h1 h2 h3 h4
    · subst h1
      simp only [eval_cons]
      rw [← add_assoc, ← add_mul, add_comm c c', h2, zero_mul, zero_add]
    · subst h1; simp only [eval_cons]; ring
    · subst h4; simp only [eval_cons]; ring
    · simp only [eval_cons]
    · simp only [eval_cons, ih]; ring

def add (p q : Poly F) : Poly F := q.foldl (fun acc t => addTerm t.1 t.2 acc) p

theorem eval_add (σ : PVar → F) (p q : Poly F) :
    eval σ (add p q) = eval σ p + eval σ q := by
  induction q generalizing p with
  | nil => simp [add]
  | cons t q ih =>
    obtain ⟨m, c⟩ := t
    simp only [add, List.foldl_cons] at *
    rw [ih, eval_addTerm, eval_cons]
    ring

/-- Multiply every term of `q` by one term and accumulate into `acc`. -/
private def scale (m : Monomial) (c : F) (q acc : Poly F) : Poly F :=
  q.foldl (fun a t => addTerm (Monomial.mul m t.1) (c * t.2) a) acc

private theorem eval_scale (σ : PVar → F) (m : Monomial) (c : F) (q acc : Poly F) :
    eval σ (scale m c q acc) = c * Monomial.eval σ m * eval σ q + eval σ acc := by
  induction q generalizing acc with
  | nil => simp [scale]
  | cons t q ih =>
    obtain ⟨m', c'⟩ := t
    simp only [scale, List.foldl_cons] at *
    rw [ih, eval_addTerm, eval_cons, Monomial.eval_mul]
    ring

def mul (p q : Poly F) : Poly F := p.foldl (fun acc t => scale t.1 t.2 q acc) []

private theorem eval_mulAux (σ : PVar → F) (p q acc : Poly F) :
    eval σ (p.foldl (fun a t => scale t.1 t.2 q a) acc)
      = eval σ p * eval σ q + eval σ acc := by
  induction p generalizing acc with
  | nil => simp
  | cons t p ih =>
    obtain ⟨m, c⟩ := t
    simp only [List.foldl_cons]
    rw [ih, eval_scale, eval_cons]
    ring

theorem eval_mul (σ : PVar → F) (p q : Poly F) :
    eval σ (mul p q) = eval σ p * eval σ q := by
  simp [mul, eval_mulAux]

/-- Negation, as multiplication by `-1`: the emitter never produces a `felt.sub`,
so subtraction on this side is spelled the same way Clean spells it. -/
def neg (p : Poly F) : Poly F := mul (const (-1)) p

@[simp] theorem eval_neg (σ : PVar → F) (p : Poly F) : eval σ (neg p) = -eval σ p := by
  simp [neg, eval_mul]

/-- `p - q`. -/
def sub (p q : Poly F) : Poly F := add p (neg q)

@[simp] theorem eval_sub (σ : PVar → F) (p q : Poly F) :
    eval σ (sub p q) = eval σ p - eval σ q := by
  simp [sub, eval_add, sub_eq_add_neg]

end Poly
end LLZK
