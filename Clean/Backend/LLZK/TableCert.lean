import Clean.Backend.LLZK.Certificate
import Clean.Gadgets.ByteLookup

/-!
# D012, discharged for the tables the corpus uses

`Clean/Backend/LLZK/Certificate.lean` states the obligation
(`ExportTable.Certifies`) and says what discharging it buys
(`certified_membership`). This module discharges it, which is why it — and not
that one — imports the gadgets the tables belong to:

* `ofStatic_certifies`, there, covers every table a caller can *derive* rather
  than assert: for any single-column `StaticTable`, the values
  `ExportTable.ofStatic` produces are exactly the ones the table contains.
* `byteTable_certifies`, here, covers `Gadgets.ByteTable`, which *cannot* use
  `ofStatic` because it inlines its `StaticTable` into `Table.fromStatic`, and
  naming that `StaticTable` breaks every proof that unfolds `ByteTable` with
  `simp`. This is the exact case D012's follow-up left open.
-/

namespace LLZK

variable {F : Type} [FiniteField F]

/-! ## `Gadgets.ByteTable`

The one table the corpus uses, and the one `ofStatic` cannot reach. -/

section ByteTable

variable {p : ℕ} [Fact p.Prime] [Fact (p > 512)]

/-- The rows `Examples.byteTable` declares, restated rather than imported: a
proof that took its definition from the module it is about would be checking
nothing. `Examples.byteTable_certified` closes the loop by `rfl`. -/
def byteRows : Array (Array Nat) := (Array.range 256).map (#[·])

@[simp] theorem mem_byteRows_values (n : Nat) :
    n ∈ (⟨"Bytes", 1, byteRows⟩ : ExportTable).values ↔ n < 256 := by
  simp [ExportTable.values, byteRows, Array.mem_flatten, Array.mem_map, Array.mem_range]

/-- **`Gadgets.ByteTable` contains exactly the field elements whose canonical
representative is a byte, which is exactly what `byteRows` lists.** -/
theorem byteTable_certifies :
    (⟨"Bytes", 1, byteRows⟩ : ExportTable).Certifies (Gadgets.ByteTable (p := p)) := by
  intro t x
  rw [mem_byteRows_values]
  show (∃ i : Fin 256, x = Gadgets.fromByte i) ↔ _
  constructor
  · rintro ⟨i, rfl⟩
    have : ZMod.val (Gadgets.fromByte (p := p) i) = i.val :=
      FieldUtils.natToField_eq _ rfl
    show ZMod.val (Gadgets.fromByte (p := p) i) < 256
    rw [this]
    exact i.is_lt
  · intro h
    refine ⟨⟨ZMod.val x, h⟩, ?_⟩
    simp [Gadgets.fromByte, FieldUtils.natToField_of_val_eq_iff]

end ByteTable

/-! ## The obligation, discharged end to end for the table the corpus uses

`certified_membership` was proved and then instantiated nowhere, and its
`hcanonical` hypothesis was never derived from the check that establishes it
(R4a-6). Both are fixed here: `ExportTable.values_lt_prime_of_diagnose` supplies
the hypothesis from the compiler's own registry check, and the theorem below is
the composition, stated about the concrete table `Addition8FullCarry` looks into.

This is the closest the project gets to an end-to-end statement on the lookup
side. What it still rests on is D017's reading of `constrain.in` as membership;
everything between Clean's `ByteTable.Contains` and the field elements the
emitted `global.def const @Bytes` holds is now a theorem.
-/

section ByteTableEndToEnd

variable {p : ℕ} [Fact p.Prime] [Fact (p > 512)]

/-- **`Gadgets.ByteTable` contains `x` exactly when the emitted `@Bytes` array
holds `x`.**

The left-hand side is Clean's lookup constraint. The right-hand side is what
`constrain.in %Bytes, %x` asserts, under D017.

**`hdiag` is a hypothesis, and nothing discharges it.** An earlier version of
this docstring said it was "discharged by the compiler before any module is
emitted", on the grounds that `ExportTable.diagnose` is the check S08 added for
R2-02. The compiler does run that check — but this theorem is instantiated at no
call site, so its hypothesis is discharged at none either, and a hypothesis of an
uninstantiated theorem is discharged by nothing. R5a-7. `GAPS.md` item 4 records
that the lookup half of `ConstraintsHoldFlat` has no *composed* semantic
theorem; this is the piece that would go in it. -/
theorem byteTable_lookup_iff
    (hdiag : ExportTable.diagnose (FiniteField.size (_root_.F p)) ⟨"Bytes", 1, byteRows⟩ = #[])
    (t : Array (_root_.F p)) (x : _root_.F p) :
    (Gadgets.ByteTable (p := p)).Contains t x
      ↔ ∃ n ∈ (⟨"Bytes", 1, byteRows⟩ : ExportTable).values, FiniteField.fromNat n = x :=
  certified_membership byteTable_certifies
    (ExportTable.values_lt_prime_of_diagnose hdiag) t x

end ByteTableEndToEnd

end LLZK
