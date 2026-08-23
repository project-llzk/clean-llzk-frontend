import Clean.Backend.LLZK.Table

/-!
# D012's obligation, and the configuration that carries it

`Table.toRaw` discards a `StaticTable`'s `length` and `row`, so the backend
cannot recover a table's rows by walking a circuit and the caller supplies them
instead. D012 recorded the consequence as a trust assumption: *we cannot check
that these rows are the table's rows.*

That is true of the compiler, and it stops mattering once the obligation is
written down and proved. `ExportTable.Certifies` below is the obligation, stated
over ordered rows at `RawTable`, the heterogeneous representation a `Lookup`
actually carries. `certified_membership` is the payoff: for a certified table
whose values are canonical — which `ExportTable.diagnose` checks since S08 —
Clean's `Contains` holds of a row exactly when that row is one of the field rows
the emitted array holds, which is what the emitted `constrain.in` asserts.

What remains assumed is a different and much smaller thing than D012 was: that
`constrain.in %table, %value` means membership. That is part of D017 and nothing
in Lean can settle it without a formal model of LLZK.

## Why this is separate from `TableCert.lean`

Everything here is generic. `TableCert.lean` discharges the obligation for the
concrete tables the corpus uses, and to do that it must import the gadgets those
tables belong to. Since S24 the supported checked compile entry points take a
`CertifiedConfig`, so whatever module defines it is imported by
`WitnessCheck.lean` — and the compiler's public surface should not transitively
depend on `Clean.Gadgets.ByteLookup` in order to say the word "certificate".
-/

namespace LLZK

variable {F : Type} [FiniteField F]

/-- The ordered canonical representatives of a raw lookup row. -/
def canonicalRow {n : Nat} (row : Vector F n) : Array Nat :=
  (row.map FiniteField.val).toArray

/-- The obligation D012 records: the exported and raw tables have the same
identity and arity, and `e.rows` is exactly the ordered canonical-row image of
the rows `table.Contains` accepts.

Quantified over the first `Contains` argument because a Clean table's
containment may in general depend on a concrete instantiation; every table
Stage 1 accepts is one for which it does not. -/
def ExportTable.Certifies (e : ExportTable) (table : RawTable F) : Prop :=
  e.name = table.name ∧ e.arity = table.arity ∧
    ∀ (t : Array (Vector F table.arity)) (row : Vector F table.arity),
      table.Contains t row ↔ canonicalRow row ∈ e.rows

/-- Canonical rows are injective because `FiniteField.val` is. -/
theorem canonicalRow_injective {n : Nat} {a b : Vector F n}
    (h : canonicalRow a = canonicalRow b) : a = b := by
  apply Vector.ext
  intro i hi
  apply FiniteField.val_injective
  have hget := congrArg (fun xs : Array Nat => xs[i]?) h
  simpa [canonicalRow, hi] using hget

/-- `ofStatic` exports exactly the canonical representatives of the table's rows. -/
theorem mem_ofStatic_rows {Row : TypeMap} [ProvableType Row]
    (st : StaticTable F Row) (row : Array Nat) :
    row ∈ (ExportTable.ofStatic st).rows ↔
      ∃ i : Fin st.length,
        row = ((toElements (M := Row) (st.row i)).map FiniteField.val).toArray := by
  simp [ExportTable.ofStatic, eq_comm]

/-- Rows derived from any `StaticTable` certify its raw table.

`ofStatic` computes them from the table's own `row` function. Passing through
`FiniteField.val` loses nothing because canonical rows are injective. -/
theorem ofStatic_certifies {Row : TypeMap} [ProvableType Row] (st : StaticTable F Row) :
    (ExportTable.ofStatic st).Certifies (Table.fromStatic st).toRaw := by
  refine ⟨rfl, rfl, ?_⟩
  intro t row
  change (∃ i, fromElements (M := Row) row = st.row i) ↔
    canonicalRow (show Vector F (size Row) from row) ∈ (ExportTable.ofStatic st).rows
  rw [mem_ofStatic_rows]
  constructor
  · rintro ⟨i, hi⟩
    refine ⟨i, ?_⟩
    have hrow := congrArg (toElements (M := Row)) hi
    simpa only [ProvableType.toElements_fromElements, canonicalRow] using
      congrArg (fun v => (v.map FiniteField.val).toArray) hrow
  · rintro ⟨i, hi⟩
    refine ⟨i, ?_⟩
    rw [ProvableType.fromElements_eq_iff]
    exact canonicalRow_injective (by simpa [canonicalRow] using hi)

/-! ## What a certificate buys

`Certifies` is about canonical representatives; the emitted global holds field
elements. This is the bridge, and it is where the range check `diagnose` has
performed since S08 (R2-02) does its work: without it `fromNat` would not invert
`val` on the declared values, and the emitted table would be a different set. -/

/-- `fromNat` reconstructs a field element from its canonical representative. -/
private theorem fromNat_val (x : F) : FiniteField.fromNat (FiniteField.val x) = x :=
  FiniteField.val_injective (FiniteField.val_fromNat _ (FiniteField.val_lt x))

/-- For a certified table with canonical values, Clean's `Contains` holds of a
row exactly when it is one of the ordered field rows the emitted array holds.

The right-hand side is the meaning of the emitted row-valued `constrain.in`, so
this says the emitted lookup constraint *is* Clean's lookup constraint. -/
theorem certified_membership {e : ExportTable} {table : RawTable F}
    (hcert : e.Certifies table)
    (hcanonical : ∀ n ∈ e.values, n < FiniteField.size F)
    (t : Array (Vector F table.arity)) (row : Vector F table.arity) :
    table.Contains t row ↔
      ∃ values ∈ e.rows, values.map FiniteField.fromNat = row.toArray := by
  rw [hcert.2.2 t row]
  constructor
  · intro hmem
    refine ⟨canonicalRow row, hmem, ?_⟩
    apply Array.ext
    · simp [canonicalRow]
    · intro i hi₁ hi₂
      simp [canonicalRow, fromNat_val]
  · rintro ⟨values, hvalues, heq⟩
    have hrow : canonicalRow row = values := by
      calc
        canonicalRow row = row.toArray.map FiniteField.val := by
          simp [canonicalRow]
        _ = (values.map FiniteField.fromNat).map FiniteField.val :=
          (congrArg (Array.map FiniteField.val) heq).symm
        _ = values := by
          apply Array.ext
          · simp
          · intro i hi₁ hi₂
            simp only [Array.getElem_map]
            rw [FiniteField.val_fromNat]
            have hiv : i < values.size := by simpa using hi₁
            exact hcanonical values[i] (Array.mem_flatten.mpr
              ⟨values, hvalues, by exact Array.getElem_mem hiv⟩)
    rwa [hrow]

/-! ## Carrying the certificate — and what that is *not*

`CertifiedConfig` is what the supported checked compile entry points take, so
the corpus's lookup tables carry their certificates next to their rows rather
than in a docstring. Changing the rows breaks the build.

**It is not a guarantee, and an earlier version of this comment said it was.**
R4a-2 broke that claim: `CertifiedTable` lets the caller choose *both* the export
table and the Clean table, and nothing ties the latter to the table the circuit's
`.lookup` operations name — that is a `RawTable`, resolved by *name* in
`recognizeLookup`, and `Table.toRaw` has already erased which `Table` it came
from. So one can define `selfTable e` with `Contains _ x := val x ∈ e.values`,
prove `e.Certifies (selfTable e)` by `Iff.rfl`, and certify any rows at all.

What this buys is therefore documentation with a proof obligation attached, not
an enforced invariant. Closing it properly needs the `Table` to survive into
`Lookup`, which is a change to Clean's core, not to this backend. Until then D012
records exactly this: the obligation is stated and proved for the tables in use,
and the compiler cannot demand it.

What S24 *did* close is the other half, which was a defect in this backend rather
than a limit of it: `Config.ofCertified` used to take `CertifiedTable`s and
return a plain `Config`, **erasing the proof it had just demanded**, so by the
time `compile` ran the certificate was gone and what remained was a convention
plus a `grep`. `CertifiedConfig` carries it to the entry point instead. See
`sessions/S23-x1-closure.md` and D022.
-/

/-- An export table together with the proof that its ordered rows are the Clean
raw table's, with the same arity and exported name.

The name conjunct is R7-12. Without it a configuration could pair rows exported
under "Bytes" with a raw table named "Foo" and vice versa; everything would
compile (lookups resolve by *name*), while `spec_of_compile`'s lookup hypothesis
would be incomparable with what the emitted module asserts. `Certifies` now
makes the names, arities, and ordered row semantics agree. It does **not** close
`GAPS.md` item 1's second half: the caller still picks both sides of `Certifies`,
and a self-referential raw table can be given any name at all. -/
structure CertifiedTable (F : Type) [FiniteField F] where
  exported : ExportTable
  table : RawTable F
  certificate : exported.Certifies table

/-- A configuration whose tables carry their certificates.

This is what the five supported checked entry points in `WitnessCheck.lean`
take. The constructor is public and `⟨spec, #[]⟩` is free — a configuration with
no lookup tables has nothing to certify, which is the honest reading. What does
not exist is any way for a *table* to get in without its proof: the field is an
`Array (CertifiedTable F)`, and there is no public function from a `Config` to
one of these. That is the whole of what the type buys, and `GAPS.md` item 1's
second half is what it does not. -/
structure CertifiedConfig (F : Type) [FiniteField F] where
  field : FieldSpec
  tables : Array (CertifiedTable F)

/-- A configuration with no lookup tables, hence nothing to certify. -/
def CertifiedConfig.forField (field : FieldSpec) : CertifiedConfig F :=
  ⟨field, #[]⟩

/-- The `Config` the rest of the compiler already understands.

Total, and deliberately so: equal name/arity and row semantics are proof fields,
so erasing them into the compiler's plain registry has no dynamic failure. The
registry diagnostics that can fail — malformed names, lookup-arity mismatches,
row widths, non-canonical values, duplicates — still run in `Analyze`.

This names `Config.unsafeWithTables`, and `scripts/llzk/check-confinement.sh`
allows it here for that reason: it is the one place where dropping to the
unproved representation is *justified by a proof that was supplied*. -/
def CertifiedConfig.toConfig (c : CertifiedConfig F) : Config :=
  Config.unsafeWithTables c.field (c.tables.map (·.exported))

/-- A certified table's export entry is one of the plain `Config`'s tables.

The bridge every theorem about `recognize cfg.toConfig …` needs, stated here so
that no proof elsewhere has to unfold `unsafeWithTables` and be reported by G12.
`Lookups.canonical_of_recognize'` is the consumer. -/
theorem CertifiedConfig.mem_toConfig_tables {c : CertifiedConfig F} {ct : CertifiedTable F}
    (h : ct ∈ c.tables) : ct.exported ∈ c.toConfig.tables :=
  Array.mem_map.mpr ⟨ct, h, rfl⟩

end LLZK
