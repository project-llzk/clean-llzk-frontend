import Clean.Backend.LLZK.WitnessCheck

/-!
# GAPS §4: the lookup half of `ConstraintsHoldFlat`, semantically

`ConstraintSet.ofSource_eqs_iff` says what the *assertion* half of the emitted
`@constrain` means: the polynomials vanish at an assignment exactly when Clean's
`FlatOperation.constraints` do. The lookup half had no counterpart.

What existed was `TableCert.byteTable_lookup_iff` — Clean's `ByteTable.Contains`
holds of `x` exactly when the emitted `@Bytes` array holds `x` — and R5a-7 found
the honest description of it: *instantiated nowhere, so its `hdiag` hypothesis is
discharged by nothing.* A hypothesis of an uninstantiated theorem is not a
guarantee, it is a wish with a proof attached.

This module supplies the two missing pieces.

## Discharging the hypotheses from the compiler's own checks

`certified_membership` needs the exported values to be canonical
(`∀ n ∈ e.values, n < FiniteField.size F`). The compiler already establishes
that, twice over, and until A1 nothing could say so:

* `ExportTable.values_lt_prime_of_diagnose` turns a clean `diagnose` into the
  bound — against `cfg.field.prime`;
* `registryOk_of_recognize` says a recognized circuit *had* a clean registry;
* `size_eq_of_recognize` says `FiniteField.size F = cfg.field.prime`, which is
  D010 as a theorem rather than as a sentence, and is what makes the two bounds
  the same bound.

`canonical_of_recognize` below is the composition. Nothing is assumed at a call
site: a module that came out of `compile` carries all three.

## What this still does not do

It does not close `GAPS.md` item 1's second half, and it cannot. Every theorem
here needs to know *which* Clean `Table` a lookup's `RawTable` came from, and
`Table.toRaw` has erased that. So the hypothesis `l.table = ct.table` is
supplied by the caller — for the corpus, by `Test/Lookups.lean`, where it holds
by `rfl` on a concrete circuit. Making the compiler *demand* it is a change to
Clean's core.

The difference from before is that the assumption is now a single named
hypothesis of a theorem that is instantiated, rather than an unstated gap between
two theorems that were not.
-/

namespace LLZK

variable {F : Type} [FiniteField F]

/-! ## The canonicity hypothesis, discharged -/

/-- **Every value in a recognized circuit's exported table rows is canonical.**

The bound `certified_membership` needs, from the checks the compiler runs rather
than from the call site. R4a-6's finding was precisely that this composition did
not exist. -/
theorem canonical_of_recognize [CanonicalRepr F] {cfg : Config} {src : Source F}
    {r : Recognized} (h : recognize cfg src = .ok r)
    {t : ExportTable} (ht : t ∈ cfg.tables) :
    ∀ n ∈ t.values, n < FiniteField.size F := by
  rw [size_eq_of_recognize h]
  exact ExportTable.values_lt_prime_of_diagnose
    (diagnose_of_mem_registry (registryOk_of_recognize h) ht)

/-- The same, for a table carried by a `CertifiedConfig` — which is what the
public entry points take, so this is the form a caller can actually reach. -/
theorem canonical_of_recognize' [CanonicalRepr F] {cfg : CertifiedConfig F} {src : Source F}
    {r : Recognized} (h : recognize cfg.toConfig src = .ok r)
    {ct : CertifiedTable F} (hct : ct ∈ cfg.tables) :
    ∀ n ∈ ct.exported.values, n < FiniteField.size F :=
  canonical_of_recognize h (CertifiedConfig.mem_toConfig_tables hct)

/-! ## Clean's lookup constraint is membership in the emitted array

`Lookup.Contains l env` is `l.table.Contains (env.data …) (l.entry.map env)`, and
for `l.table = T.toRaw` that unfolds to `T.Contains` of the `fromElements` of
both. `Certifies` is quantified over the table argument for exactly this reason:
the array a lookup is resolved against comes from the environment, and no
certificate can say anything about it. -/

/-- **A certified lookup means what the emitted `constrain.in` means.**

The left-hand side is Clean's own lookup constraint, the conjunct
`ConstraintsHoldFlat` contributes for a `.lookup` operation. The right-hand side
is membership in the ordered rows the emitted `global.def const` holds, which is
what row-valued `constrain.in` asserts under D017.

Stated for a `Lookup` built from the certified raw table rather than for one
whose `table` field merely equals it, because `Lookup.entry`'s type depends on
`table.arity`; a caller with that equality destructures `l` and substitutes. -/
theorem certified_lookup_contains_iff {T : RawTable F} {e : ExportTable}
    (hcert : e.Certifies T) (hcanon : ∀ n ∈ e.values, n < FiniteField.size F)
    (entry : Vector (Expression F) T.arity) (env : Environment F) :
    Lookup.Contains ⟨T, entry⟩ env
      ↔ ∃ values ∈ e.rows,
          values.map FiniteField.fromNat = (entry.map env).toArray :=
  certified_membership hcert hcanon _ _

/-- The queried value for the retained one-column compatibility path: the
lookup's one expression, evaluated.

`fromElements` for `field` is the first component, so this is the value
`ConstraintSet.ofSource` reads as `Expression.toPoly`. Not `rfl`: `Vector.map`
does not reduce on a literal, so it takes `explicit_provable_type`. -/
theorem fromElements_map_env (x : Expression F) (env : Environment F) :
    fromElements (M := field) ((#v[x] : Vector (Expression F) (size field)).map env)
      = x.eval env := by
  simp [explicit_provable_type]

/-! ## The composed statement

The shape mirrors `ConstraintSet.ofSource_eqs_iff`: the left-hand side is what
the comparison in `Constraints.lean` reads out of the module, the right-hand side
is Clean's own semantics. Together the two theorems cover both conjuncts of
`constraintsHoldFlat_iff_forall_mem`. -/

/-- **The emitted lookup polynomials are Clean's lookup constraints.**

`resolve` is the caller's account of which Clean `Table` each lookup names, and
supplying it is `GAPS.md` item 1's second half — the compiler cannot. Given it,
every `(name, p)` pair `ConstraintSet.ofSource` produces evaluates into the
emitted table's values exactly when Clean's `Lookup.Contains` holds.

Note which direction the quantifier runs: this is stated over the lookups of the
*source*, so it composes with `lookups_perm_of_compileSource'`, which says the
module's are a permutation of these. -/
theorem ofSource_lookups_iff [CanonicalRepr F] {cfg : CertifiedConfig F} {src : Source F}
    {r : Recognized} (hrec : recognize cfg.toConfig src = .ok r) (env : Environment F)
    (resolve : ∀ l ∈ FlatOperation.lookups src.operations,
      ∃ ct ∈ cfg.tables, ∃ entry : Vector (Expression F) ct.table.arity,
        l = ⟨ct.table, entry⟩) :
    (∀ l ∈ FlatOperation.lookups src.operations, l.Contains env)
      ↔ (∀ l ∈ FlatOperation.lookups src.operations, ∀ ct ∈ cfg.tables,
          ∀ entry : Vector (Expression F) ct.table.arity, l = ⟨ct.table, entry⟩ →
            ∃ values ∈ ct.exported.rows,
              values.map FiniteField.fromNat = (entry.map env).toArray) := by
  constructor
  · intro hall l hl ct hct entry heq
    have := hall l hl
    rw [heq] at this
    exact (certified_lookup_contains_iff ct.certificate
      (canonical_of_recognize' hrec hct) entry env).mp this
  · intro hall l hl
    obtain ⟨ct, hct, entry, heq⟩ := resolve l hl
    rw [heq]
    exact (certified_lookup_contains_iff ct.certificate
      (canonical_of_recognize' hrec hct) entry env).mpr (hall l hl ct hct entry heq)

end LLZK
