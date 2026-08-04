import Clean.Backend.LLZK.Lookups
import Clean.Backend.LLZK.Examples

/-!
# GAPS §4, instantiated

`Lookups.lean` has the general theorems. This module is the half of §4 that a
general theorem cannot supply: **it applies them to a circuit.**

R5a-7's finding was not that `byteTable_lookup_iff` was wrong. It was that it was
*instantiated nowhere*, so its `hdiag` hypothesis — "the compiler's registry check
passed" — was discharged at no call site, and a hypothesis nothing discharges is
not a guarantee. The same was true of `certified_membership` before it.

Both are discharged here, for `Gadgets.Addition8FullCarry` under `withBytes`,
which is the corpus's only circuit with a lookup and the gadget the whole Stage-1
target was chosen around. Nothing is assumed about the table that the compiler
does not itself check, and nothing is assumed about the circuit that is not
proved from its own operations.

## The one hypothesis that stays

`recognize withBytes.toConfig addSrc = .ok r` — the compiler accepted this
circuit. It is a hypothesis rather than a discharged fact because `recognize` on
a real gadget does not reduce in the kernel (the operation list carries
`Expression`s and `Fact` instances), so `rfl` cannot close it and the only tools
that could are `native_decide`, which `GAPS.md` item 8 already objects to
carrying more of. The `#guard` below evaluates it instead, which is the same
check the corpus and gate G1 run.

`resolve` — which Clean `Table` each lookup's `RawTable` came from — *is* proved,
by unfolding the gadget. That is `GAPS.md` item 1's second half supplied by hand
for one circuit; the compiler still cannot demand it.
-/

namespace LLZK.Test.Lookups

open LLZK LLZK.Examples

abbrev Bab := F pBabybear

private def addSrc : Source Bab :=
  Compilable.source (Gadgets.Addition8FullCarry.circuit (p := pBabybear))

-- The compiler accepts this circuit, which is the one hypothesis below that is
-- checked rather than proved. Same check as G1 and the corpus.
#guard (recognize withBytes.toConfig addSrc).isOk

private def bytesCert : CertifiedTable Bab :=
  ⟨byteTable, Gadgets.ByteTable, byteTable_certified⟩

private theorem bytesCert_mem : bytesCert ∈ withBytes.tables := by
  simp [withBytes, bytesCert]

/-- **Every lookup `Addition8FullCarry` performs is into `Gadgets.ByteTable`.**

Proved from the gadget's own operations, not asserted: `main` does `lookup
ByteTable z` and nothing else that looks anything up, and the `assertBool`
subcircuit it inlines contributes only an assertion. This is what
`GAPS.md` item 1's second half asks a caller to supply, supplied. -/
theorem add8_lookups_are_byteTable : ∀ l ∈ FlatOperation.lookups addSrc.operations,
    l.table = (Gadgets.ByteTable (p := pBabybear)).toRaw := by
  simp [circuit_norm, addSrc, Compilable.source, Source.ofFormalCircuit,
    Gadgets.Addition8FullCarry.circuit, Gadgets.Addition8FullCarry.main,
    FlatOperation.lookups, FormalAssertion.toSubcircuit, Operations.toFlat]

/-- The same fact in the shape `ofSource_lookups_iff` consumes. -/
theorem add8_resolve : ∀ l ∈ FlatOperation.lookups addSrc.operations,
    ∃ ct ∈ withBytes.tables, ∃ entry : Vector (Expression Bab) ct.table.toRaw.arity,
      l = ⟨ct.table.toRaw, entry⟩ := by
  intro l hl
  obtain ⟨tbl, entry⟩ := l
  have htbl : tbl = (Gadgets.ByteTable (p := pBabybear)).toRaw := add8_lookups_are_byteTable _ hl
  subst htbl
  exact ⟨bytesCert, bytesCert_mem, entry, rfl⟩

/-- **`Addition8FullCarry`'s lookup constraints are membership in the emitted
`@Bytes` array.**

`ofSource_lookups_iff` instantiated. The left-hand side is the lookup half of
Clean's `ConstraintsHoldFlat` for this circuit; the right-hand side is what the
emitted `constrain.in %Bytes, %v` asserts under D017. Everything between them is
a theorem, and every hypothesis but the compile itself is discharged: the
canonicity bound comes from `registryOk_of_recognize` and `size_eq_of_recognize`,
and the table identity from `add8_lookups_are_byteTable`.

With `ConstraintSet.ofSource_eqs_iff` this covers both conjuncts of
`constraintsHoldFlat_iff_forall_mem`. -/
theorem add8_lookup_iff {r : Recognized}
    (hrec : recognize withBytes.toConfig addSrc = .ok r) (env : Environment Bab) :
    (∀ l ∈ FlatOperation.lookups addSrc.operations, l.Contains env)
      ↔ (∀ l ∈ FlatOperation.lookups addSrc.operations, ∀ ct ∈ withBytes.tables,
          ∀ entry : Vector (Expression Bab) ct.table.toRaw.arity, l = ⟨ct.table.toRaw, entry⟩ →
            ∃ n ∈ ct.exported.values, FiniteField.fromNat n = fromElements (entry.map env)) :=
  ofSource_lookups_iff hrec env add8_resolve

/-! ## `byteTable_lookup_iff`, with `hdiag` discharged

The theorem R5a-7 named. Its hypothesis is the compiler's own registry check, and
this is the call site that supplies it — from `registryOk_of_recognize` rather
than from a 256-row kernel computation, which is both cheaper and the thing the
docstring wanted to be able to say. -/

theorem byteTable_diagnose_ok {r : Recognized}
    (hrec : recognize withBytes.toConfig addSrc = .ok r) :
    ExportTable.diagnose (FiniteField.size Bab) (⟨"Bytes", 1, byteRows⟩ : ExportTable) = #[] := by
  rw [size_eq_of_recognize hrec]
  refine diagnose_of_mem_registry (registryOk_of_recognize hrec) ?_
  simp [CertifiedConfig.toConfig, Config.unsafeWithTables, withBytes, byteTable, byteRows]

/-- **Clean's `ByteTable.Contains` is exactly what the emitted `@Bytes` holds**,
with nothing left hypothetical but the compile. -/
theorem byteTable_lookup_iff_of_recognize {r : Recognized}
    (hrec : recognize withBytes.toConfig addSrc = .ok r)
    (t : Array Bab) (x : Bab) :
    (Gadgets.ByteTable (p := pBabybear)).Contains t x
      ↔ ∃ n ∈ (⟨"Bytes", 1, byteRows⟩ : ExportTable).values, FiniteField.fromNat n = x :=
  byteTable_lookup_iff (byteTable_diagnose_ok hrec) t x

end LLZK.Test.Lookups
