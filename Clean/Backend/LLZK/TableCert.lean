import Clean.Backend.LLZK.Table
import Clean.Gadgets.ByteLookup

/-!
# D012, discharged: the exported rows are the table's rows

`Table.toRaw` discards a `StaticTable`'s `length` and `row`, so the backend
cannot recover a table's rows by walking a circuit and the caller supplies them
through `Config.tables`. D012 recorded the consequence as a trust assumption:
*we cannot check that these rows are the table's rows.*

That is true of the compiler, and it stops mattering once the obligation is
written down and proved. `ExportTable.Certifies` below is the obligation, stated
over `rows.flatten` because that is exactly the value list `Circuit.lower`
puts into the emitted `global.def const`. Two theorems discharge it for every
table the corpus uses:

* `ofStatic_certifies` — for any single-column `StaticTable`, the values
  `ExportTable.ofStatic` derives are exactly the ones the table contains. This
  covers every table a caller can derive rather than assert.
* `byteTable_certifies` — for `Gadgets.ByteTable`, which *cannot* use `ofStatic`
  because it inlines its `StaticTable` into `Table.fromStatic`, and naming that
  `StaticTable` breaks every proof that unfolds `ByteTable` with `simp`. This is
  the exact case D012's follow-up left open.

`certified_membership` is the payoff: for a certified table whose values are
canonical — which `ExportTable.diagnose` checks since S08 — Clean's `Contains`
holds of a value exactly when that value is one of the field elements the emitted
array holds, which is what the emitted `constrain.in` asserts.

What remains assumed is a different and much smaller thing than D012 was: that
`constrain.in %table, %value` means membership. That is part of D017 and nothing
in Lean can settle it without a formal model of LLZK.
-/

namespace LLZK

variable {F : Type} [FiniteField F]

/-- The obligation D012 records: `e`'s values are exactly the canonical
representatives of the elements the single-column Clean table `table` contains.

Quantified over the `Array` argument of `Contains` because a Clean table's
containment may in general depend on a concrete instantiation; every table
Stage 1 accepts is one for which it does not. -/
def ExportTable.Certifies (e : ExportTable) (table : Table F field) : Prop :=
  ∀ (t : Array F) (x : F), table.Contains t x ↔ FiniteField.val x ∈ e.values

/-- `ofStatic` exports exactly the canonical representatives of the table's rows. -/
theorem mem_ofStatic_values (st : StaticTable F field) (n : Nat) :
    n ∈ (ExportTable.ofStatic st).values ↔ ∃ i : Fin st.length, n = FiniteField.val (st.row i) := by
  simp [ExportTable.values, ExportTable.ofStatic, explicit_provable_type]

/-- Values derived from a `StaticTable` are the table's values.

`ofStatic` computes them from the table's own `row` function, so the only content
is that passing through `FiniteField.val` loses nothing — `val_injective`. -/
theorem ofStatic_certifies (st : StaticTable F field) :
    (ExportTable.ofStatic st).Certifies (Table.fromStatic st) := by
  intro t x
  rw [mem_ofStatic_values]
  show (∃ i, x = st.row i) ↔ _
  constructor
  · rintro ⟨i, rfl⟩
    exact ⟨i, rfl⟩
  · rintro ⟨i, hi⟩
    exact ⟨i, FiniteField.val_injective hi⟩

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

/-! ## What a certificate buys

`Certifies` is about canonical representatives; the emitted global holds field
elements. This is the bridge, and it is where the range check `diagnose` has
performed since S08 (R2-02) does its work: without it `fromNat` would not invert
`val` on the declared values, and the emitted table would be a different set. -/

/-- For a certified table with canonical values, Clean's `Contains` holds of `x`
exactly when `x` is one of the field elements the emitted array holds.

The right-hand side is the meaning of the emitted `constrain.in %table, %x`, so
this says the emitted lookup constraint *is* Clean's lookup constraint. -/
theorem certified_membership {e : ExportTable} {table : Table F field}
    (hcert : e.Certifies table)
    (hcanonical : ∀ n ∈ e.values, n < FiniteField.size F)
    (t : Array F) (x : F) :
    table.Contains t x ↔ ∃ n ∈ e.values, FiniteField.fromNat n = x := by
  rw [hcert t x]
  constructor
  · intro hmem
    exact ⟨FiniteField.val x, hmem,
      FiniteField.val_injective (FiniteField.val_fromNat _ (FiniteField.val_lt x))⟩
  · rintro ⟨n, hn, rfl⟩
    rwa [FiniteField.val_fromNat n (hcanonical n hn)]

/-! ## Carrying the certificate — and what that is *not*

`Config.ofCertified` below takes tables paired with their proofs, and
`Examples.withBytes` uses it, so the corpus's only lookup table carries its
certificate next to the rows rather than in a docstring. Changing the rows breaks
the build.

**It is not a guarantee, and an earlier version of this comment said it was.**
R4a-2 broke that claim: `CertifiedTable` lets the caller choose *both* the export
table and the Clean table, and nothing ties the latter to the table the circuit's
`.lookup` operations name — that is a `RawTable`, resolved by *name* in
`recognizeLookup`, and `Table.toRaw` has already erased which `Table` it came
from. So one can define `selfTable e` with `Contains _ x := val x ∈ e.values`,
prove `e.Certifies (selfTable e)` by `Iff.rfl`, and certify any rows at all.
`Config.mk` is public too.

What this buys is therefore documentation with a proof obligation attached, not
an enforced invariant. Closing it properly needs the `Table` to survive into
`Lookup`, which is a change to Clean's core, not to this backend. Until then D012
records exactly this: the obligation is stated and proved for the tables in use,
and the compiler cannot demand it.
-/

/-- An export table together with the proof that its values are the Clean
table's. -/
structure CertifiedTable (F : Type) [FiniteField F] where
  exported : ExportTable
  table : Table F field
  certificate : exported.Certifies table

/-- Build a configuration from tables that carry their certificates.

Since R5's X1 this is the only way to supply tables without naming
`Config.unsafeWithTables`, which `scripts/llzk/check-unsafe-config.sh` forbids
outside `Test/`. Still not a guarantee about the circuit's table; see the
section comment above. -/
def Config.ofCertified (spec : FieldSpec) (tables : Array (CertifiedTable F)) : Config :=
  Config.unsafeWithTables spec (tables.map (·.exported))

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
