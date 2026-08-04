import Clean.Circuit.Theorems
import Clean.Circuit.Subcircuit
import Clean.Backend.LLZK.Lookups

/-!
# GAPS §3: from the emitted module's constraints to the gadget's `Spec`

The statement a user most likely assumes this project has, and until now the one
it did not. `eqs_iff_of_compileSource'` stops at `ConstraintsHoldFlat`; a
`FormalCircuit`'s `soundness` field is stated over `ConstraintsHold.Soundness`,
which is a different and stronger predicate — it replaces each subcircuit's
constraints by its `Assumptions → Spec`.

The chain has four links, and three of them are Clean's own:

1. `ConstraintSet.eqs_iff_of_agree` and `Lookups.ofSource_lookups_iff` — the two
   conjuncts of `constraintsHoldFlat_iff_forall_mem`, from the emitted module.
   The second is A1; before it this chain could not be built at all.
2. `Circuit.constraintsHold_toFlat_iff` — Clean's own bridge between the flat and
   nested representations.
3. `Circuit.can_replace_soundness` — Clean's own step to `ConstraintsHold.Soundness`,
   which needs `Operations.FullGuarantees`.
4. the gadget's own `soundness` field.

## Why `FullGuarantees` is free here

`Operations.FullGuarantees env ops` is `∀ i ∈ ops.interactions, i.Guarantees env`
— a statement about *channel interactions*, which this backend does not accept:
`Analyze.recognizeOperation` refuses `.interact` by name, so no circuit that
compiles has one. The hypothesis below is therefore `interactions = []`, and it is
discharged by the same `simp` that unfolds a concrete gadget.

That is worth stating plainly, because it is the one place where Stage 1's
*narrowness* buys something rather than costing something: the capability
boundary D004 drew for fail-closed reasons happens to also discharge the side
condition Clean's soundness bridge needs.

## What this does and does not say

It says: **if the emitted module's `@constrain` is satisfied at an assignment,
and the gadget's `Assumptions` hold of the input there, then the gadget's `Spec`
holds of the input and the output that assignment gives.** That is the soundness
direction, for the module rather than for the circuit.

It does not say anything about completeness — that the module *has* a satisfying
assignment — and it does not remove D017. Every hypothesis about the emitted side
is stated in terms of the `ConstraintSet` the reader extracts from the module, so
"the module is satisfied" still means "satisfied under the reading of LLZK that
D017 records". GAPS §2 (the renderer) also still stands between the `Module` and
the text.
-/

namespace LLZK

open ConstraintSet

variable {F : Type} [FiniteField F] [DecidableEq F]

/-! ## The emitted side -/

/-- `eqs_iff_of_compileSource'` needs only the comparison, not the compile.

Factored out because `compile` goes through `compileSourceVerified`, whose
guarantee is `constraintsAgree_of_compileSourceVerified` — an `agree`, not a
`compileSource'`. Same proof. -/
theorem ConstraintSet.eqs_iff_of_agree {cfg : Config} {src : Source F} {m : Module}
    {C : ConstraintSet F} (ha : agree cfg src m = true) (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (env : Environment F) (outs : Nat → F) :
    (∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
      ↔ (∀ e ∈ FlatOperation.constraints src.operations, e.eval env = 0)
        ∧ (∀ e j, (e, j) ∈ src.outputs.toList.zipIdx → outs j = e.eval env) := by
  simp only [agree, hm, Bool.and_eq_true] at ha
  have hperm : C.eqs.Perm (ofSource cfg src).eqs := List.isPerm_iff.mp ha.1.2
  rw [← ofSource_eqs_iff cfg src env outs]
  exact ⟨fun hh p hp => hh p (hperm.mem_iff.mpr hp),
         fun hh p hp => hh p (hperm.mem_iff.mp hp)⟩

/-- **Both conjuncts of `ConstraintsHoldFlat`, from the emitted module.**

The assertion half comes from the polynomial comparison, the lookup half from A1.
Together they are exactly `constraintsHoldFlat_iff_forall_mem`'s right-hand side. -/
theorem constraintsHoldFlat_of_emitted [CanonicalRepr F] {cfg : CertifiedConfig F}
    {src : Source F} {m : Module} {C : ConstraintSet F} {r : Recognized}
    (ha : agree cfg.toConfig src m = true)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (hrec : recognize cfg.toConfig src = .ok r)
    (resolve : ∀ l ∈ FlatOperation.lookups src.operations,
      ∃ ct ∈ cfg.tables, ∃ entry : Vector (Expression F) ct.table.toRaw.arity,
        l = ⟨ct.table.toRaw, entry⟩)
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups src.operations, ∀ ct ∈ cfg.tables,
      ∀ entry : Vector (Expression F) ct.table.toRaw.arity, l = ⟨ct.table.toRaw, entry⟩ →
        ∃ n ∈ ct.exported.values, FiniteField.fromNat n = fromElements (entry.map env)) :
    FlatOperation.ConstraintsHoldFlat env src.operations := by
  rw [FlatOperation.constraintsHoldFlat_iff_forall_mem]
  exact ⟨(eqs_iff_of_agree ha hm env outs).mp heqs |>.1,
         (ofSource_lookups_iff hrec env resolve).mpr hlookups⟩

/-! ## The Clean side -/

variable {Input Output : TypeMap} [ProvableType Input] [ProvableType Output]

omit [DecidableEq F] in
/-- **Clean's flat constraints imply the gadget's `Spec`.**

Links 2–4 of the chain, and none of it is new mathematics: `constraintsHold_toFlat_iff`
and `can_replace_soundness` are Clean's, and the last step is the gadget's own
`soundness` field. What this contributes is that they are composed at the exact
offset and instantiation `Source.ofFormalCircuit` uses, which is the point where a
mismatch would otherwise hide.

`hnoint` is discharged for anything this backend accepts — see the module
docstring. -/
theorem spec_of_constraintsHoldFlat (c : FormalCircuit F Input Output) (env : Environment F)
    (hflat : FlatOperation.ConstraintsHoldFlat env (Source.ofFormalCircuit c).operations)
    (hnoint : ((c.main (varFromOffset Input 0)).operations (size Input)).interactions = [])
    (input : Input F)
    (hinput : eval env (varFromOffset Input 0 : Var Input F) = input)
    (hassm : c.Assumptions input) :
    c.Spec input (eval env (c.output (varFromOffset Input 0) (size Input))) := by
  have hch : ((c.main (varFromOffset Input 0)).operations (size Input)).ConstraintsHold env :=
    Circuit.constraintsHold_toFlat_iff.mp hflat
  have hguar : ((c.main (varFromOffset Input 0)).operations (size Input)).FullGuarantees env := by
    intro i hi; rw [hnoint] at hi; simp at hi
  exact (c.soundness (size Input) env (varFromOffset Input 0) input hinput hassm
    (Circuit.can_replace_soundness hch hguar)).1

/-! ## The composition -/

/-- **The emitted module's constraints imply the gadget's `Spec`.**

`GAPS.md` §3, for a circuit whose lookups resolve to certified tables and which
has no channel interactions — the second holds of everything this backend
accepts, and the first is §1's second half, supplied by the caller.

Read the hypotheses as a list of what a satisfying assignment of the *module*
consists of: values for the circuit's cells (`env`), values for the `@out{j}`
members D008 adds (`outs`), every emitted polynomial vanishing, and every emitted
lookup satisfied. The conclusion is the gadget's own `Spec`, which is what its
`soundness` field is about.

`compile` is the hypothesis rather than `compileSourceVerified` because it is the
public entry point, and it takes a `CertifiedConfig`, so a table cannot reach it
without its certificate. -/
theorem spec_of_compile [CanonicalRepr F] {cfg : CertifiedConfig F}
    {c : FormalCircuit F Input Output} {m : Module} {C : ConstraintSet F} {r : Recognized}
    (hcompile : compile cfg c = .ok m)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (hrec : recognize cfg.toConfig (Compilable.source (F := F) c) = .ok r)
    (resolve : ∀ l ∈ FlatOperation.lookups (Compilable.source (F := F) c).operations,
      ∃ ct ∈ cfg.tables, ∃ entry : Vector (Expression F) ct.table.toRaw.arity,
        l = ⟨ct.table.toRaw, entry⟩)
    (hnoint : ((c.main (varFromOffset Input 0)).operations (size Input)).interactions = [])
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups (Compilable.source (F := F) c).operations,
      ∀ ct ∈ cfg.tables, ∀ entry : Vector (Expression F) ct.table.toRaw.arity,
        l = ⟨ct.table.toRaw, entry⟩ →
          ∃ n ∈ ct.exported.values, FiniteField.fromNat n = fromElements (entry.map env))
    (input : Input F)
    (hinput : eval env (varFromOffset Input 0 : Var Input F) = input)
    (hassm : c.Assumptions input) :
    c.Spec input (eval env (c.output (varFromOffset Input 0) (size Input))) :=
  spec_of_constraintsHoldFlat c env
    (constraintsHoldFlat_of_emitted (constraintsAgree_of_compileSourceVerified hcompile)
      hm hrec resolve env outs heqs hlookups)
    hnoint input hinput hassm

end LLZK
