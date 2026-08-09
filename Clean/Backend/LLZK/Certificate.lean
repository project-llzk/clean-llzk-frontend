import Clean.Backend.LLZK.Table

/-!
# D012's obligation, and the configuration that carries it

`Table.toRaw` discards a `StaticTable`'s `length` and `row`, so the backend
cannot recover a table's rows by walking a circuit and the caller supplies them
instead. D012 recorded the consequence as a trust assumption: *we cannot check
that these rows are the table's rows.*

That is true of the compiler, and it stops mattering once the obligation is
written down and proved. `ExportTable.Certifies` below is the obligation, stated
over `rows.flatten` because that is exactly the value list `Circuit.lower` puts
into the emitted `global.def const`. `certified_membership` is the payoff: for a
certified table whose values are canonical — which `ExportTable.diagnose` checks
since S08 — Clean's `Contains` holds of a value exactly when that value is one of
the field elements the emitted array holds, which is what the emitted
`constrain.in` asserts.

What remains assumed is a different and much smaller thing than D012 was: that
`constrain.in %table, %value` means membership. That is part of D017 and nothing
in Lean can settle it without a formal model of LLZK.

## Why this is separate from `TableCert.lean`

Everything here is generic. `TableCert.lean` discharges the obligation for the
concrete tables the corpus uses, and to do that it must import the gadgets those
tables belong to. Since S24 the public compile entry points take a
`CertifiedConfig`, so whatever module defines it is imported by
`WitnessCheck.lean` — and the compiler's public surface should not transitively
depend on `Clean.Gadgets.ByteLookup` in order to say the word "certificate".
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

`CertifiedConfig` is what the public compile entry points take, so the corpus's
lookup tables carry their certificates next to their rows rather than in a
docstring. Changing the rows breaks the build.

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

/-- An export table together with the proof that its values are the Clean
table's — and that it is exported under that table's own name.

The name field is R7-12. `Certifies` constrains values only, so without it a
configuration could pair exported rows named "Bytes" with a Clean table named
"Foo" and vice versa; everything would compile (lookups resolve by *name*), and
then `spec_of_compile`'s lookup hypothesis — stated over the Clean table via
`Certifies` — would be incomparable with what the emitted module asserts, which
is membership in the global *named* `l.table.name`. The tie makes the two speak
about the same global. It does **not** close `GAPS.md` item 1's second half:
the caller still picks both sides of `Certifies`, and a `selfTable` can be
given any name at all. -/
structure CertifiedTable (F : Type) [FiniteField F] where
  exported : ExportTable
  table : Table F field
  certificate : exported.Certifies table
  name_certifies : exported.name = table.name

/-- A configuration whose tables carry their certificates.

This is what every public entry point in `WitnessCheck.lean` takes. The
constructor is public and `⟨spec, #[]⟩` is free — a configuration with no lookup
tables has nothing to certify, which is the honest reading. What does not exist
is any way for a *table* to get in without its proof: the field is an
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

Total, and deliberately so: a certificate constrains a table's *rows*, never its
shape, so there is nothing here that can fail. The registry diagnostics that can
fail — malformed names, arity mismatches, non-canonical values, duplicates — run
where they ran before, in `Analyze`.

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
