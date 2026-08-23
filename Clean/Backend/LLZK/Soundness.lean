import Clean.Circuit.Theorems
import Clean.Circuit.Subcircuit
import Clean.Backend.LLZK.Lookups

/-!
# GAPS §3: from the emitted module's constraints to the gadget's `Spec`

The statement a user most likely assumes this project has, and before A2 the one
it did not. G9's data-level agreement stops at `ConstraintsHoldFlat`; a
`FormalCircuit`'s `soundness` field is stated over `ConstraintsHold.Soundness`,
which is a different and stronger predicate — it replaces each subcircuit's
constraints by its `Assumptions → Spec`.

The chain has four links, and three of them are Clean's own:

1. `ConstraintSet.eqs_iff_of_agree`, `lookupRows_of_agree`, and
   `Lookups.ofSource_lookups_iff` — the two conjuncts of
   `constraintsHoldFlat_iff_forall_mem`, from the emitted module. The middle
   bridge makes the lookup premise range over `C.lookups`, not a restatement of
   the source list.
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
holds of the input and the typed output reconstructed from that assignment's
ordered `@out{j}` members.** That is the soundness direction, for the module
rather than only for the circuit's internally recomputed output expressions.

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

/-- Semantic satisfaction of the lookup rows the independent module reader
extracts.

For every ordered polynomial row in `C.lookups`, evaluating that row must yield
one ordered row of every same-named entry in `C.globals`. Both sides therefore
come from the independent module reader. `agree` and the certificate bridge
those global rows to Clean's raw table; D017 remains the assumption that LLZK
gives `constrain.in` this membership meaning. -/
def ConstraintSet.LookupRowsHold (C : ConstraintSet F)
    (env : Environment F) (outs : Nat → F) : Prop :=
  ∀ name row, (name, row) ∈ C.lookups →
    ∀ rows, (name, rows) ∈ C.globals →
      ∃ values ∈ rows,
        values.map FiniteField.fromNat = row.map (Poly.eval (assign env outs))

/-- Give G9's equality agreement its semantic meaning without requiring a
particular compilation entry point. `compile` goes through
`compileSourceVerified`, whose guarantee is an `agree`, so this is the reusable
form consumed by the soundness chain. -/
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

/-- The module reader's ordered lookup rows are a permutation of the source
reader's ordered lookup rows whenever G9 agrees. -/
theorem ConstraintSet.lookups_perm_of_agree {cfg : Config} {src : Source F} {m : Module}
    {C : ConstraintSet F} (ha : agree cfg src m = true)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C) :
    C.lookups.Perm (ofSource cfg src).lookups := by
  simp only [agree, hm, Bool.and_eq_true] at ha
  exact List.isPerm_iff.mp ha.2

/-- Convert semantic satisfaction of the module reader's lookup rows into the
source-indexed certified-row premise consumed by `ofSource_lookups_iff`.

This is the name/arity bridge R7-12 left open. The lookup permutation comes from
G9, the table name equality comes from `ExportTable.Certifies`, and evaluation
of each retained polynomial is `Expression.eval`. -/
theorem ConstraintSet.lookupRows_of_agree {cfg : CertifiedConfig F} {src : Source F}
    {m : Module} {C : ConstraintSet F}
    (ha : agree cfg.toConfig src m = true)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (env : Environment F) (outs : Nat → F)
    (hlookups : C.LookupRowsHold env outs) :
    ∀ l ∈ FlatOperation.lookups src.operations, ∀ ct ∈ cfg.tables,
      ∀ entry : Vector (Expression F) ct.table.arity, l = ⟨ct.table, entry⟩ →
        ∃ values ∈ ct.exported.rows,
          values.map FiniteField.fromNat = (entry.map env).toArray := by
  intro l hl ct hct entry heq
  have hsource : (l.table.name, l.entry.toArray.map Expression.toPoly) ∈
      (ofSource cfg.toConfig src).lookups := by
    simp only [ofSource]
    exact List.mem_map.mpr ⟨l, hl, rfl⟩
  have hmodule : (l.table.name, l.entry.toArray.map Expression.toPoly) ∈ C.lookups :=
    (lookups_perm_of_agree ha hm).mem_iff.mpr hsource
  have hused : (FlatOperation.lookups src.operations).any
      (fun l => l.table.name = ct.exported.name) := by
    apply List.any_eq_true.mpr
    refine ⟨l, hl, ?_⟩
    simp only [heq]
    exact decide_eq_true ct.certificate.1.symm
  have hsourceGlobal : (ct.exported.name, ct.exported.rows) ∈
      (ofSource cfg.toConfig src).globals := by
    simp only [ofSource]
    apply List.mem_map.mpr
    refine ⟨ct.exported, ?_, rfl⟩
    have hmem : ct.exported ∈
        cfg.toConfig.tables.filter (fun table =>
          (FlatOperation.lookups src.operations).any (·.table.name = table.name)) :=
      Array.mem_filter.mpr ⟨CertifiedConfig.mem_toConfig_tables hct, hused⟩
    simpa using hmem
  have hm' : ofModule (F := F) (Ty.felt cfg.toConfig.field.name) m = some C := by
    change ofModule (F := F) (Ty.felt cfg.field.name) m = some C
    exact hm
  have hagree := ha
  simp only [agree, hm', Bool.and_eq_true] at hagree
  have hglobal : (ct.exported.name, ct.exported.rows) ∈ C.globals := by
    rw [beq_iff_eq.mp hagree.1.1.2]
    exact hsourceGlobal
  rw [heq] at hmodule
  obtain ⟨values, hvalues, hrow⟩ :=
    hlookups ct.exported.name (entry.toArray.map Expression.toPoly)
      (by simpa only [ct.certificate.1] using hmodule)
      ct.exported.rows hglobal
  refine ⟨values, hvalues, ?_⟩
  rw [hrow]
  apply Array.ext
  · simp
  · intro i hi₁ hi₂
    simp [Expression.eval_toPoly]

/-- Both conjuncts of `ConstraintsHoldFlat`, with the lookup rows already
indexed by the source.

Kept as the explicit compatibility form for callers that already have Clean's
lookup premise. The public `constraintsHoldFlat_of_emitted` below accepts
semantic satisfaction of `C.lookups` and proves this source-indexed premise. -/
theorem constraintsHoldFlat_of_sourceRows [CanonicalRepr F] {cfg : CertifiedConfig F}
    {src : Source F} {m : Module} {C : ConstraintSet F} {r : Recognized}
    (ha : agree cfg.toConfig src m = true)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (hrec : recognize cfg.toConfig src = .ok r)
    (resolve : ∀ l ∈ FlatOperation.lookups src.operations,
      ∃ ct ∈ cfg.tables, ∃ entry : Vector (Expression F) ct.table.arity,
        l = ⟨ct.table, entry⟩)
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups src.operations, ∀ ct ∈ cfg.tables,
      ∀ entry : Vector (Expression F) ct.table.arity, l = ⟨ct.table, entry⟩ →
        ∃ values ∈ ct.exported.rows,
          values.map FiniteField.fromNat = (entry.map env).toArray) :
    FlatOperation.ConstraintsHoldFlat env src.operations := by
  rw [FlatOperation.constraintsHoldFlat_iff_forall_mem]
  exact ⟨(eqs_iff_of_agree ha hm env outs).mp heqs |>.1,
         (ofSource_lookups_iff hrec env resolve).mpr hlookups⟩

/-- **Both conjuncts of `ConstraintsHoldFlat`, from the emitted module.**

The assertion half comes from the polynomial comparison, the lookup half from A1.
The lookup premise ranges over `C.lookups`, not a separately restated source
list; `lookupRows_of_agree` proves the bridge between them. Together they are
exactly `constraintsHoldFlat_iff_forall_mem`'s right-hand side. -/
theorem constraintsHoldFlat_of_emitted [CanonicalRepr F] {cfg : CertifiedConfig F}
    {src : Source F} {m : Module} {C : ConstraintSet F} {r : Recognized}
    (ha : agree cfg.toConfig src m = true)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (hrec : recognize cfg.toConfig src = .ok r)
    (resolve : ∀ l ∈ FlatOperation.lookups src.operations,
      ∃ ct ∈ cfg.tables, ∃ entry : Vector (Expression F) ct.table.arity,
        l = ⟨ct.table, entry⟩)
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : C.LookupRowsHold env outs) :
    FlatOperation.ConstraintsHoldFlat env src.operations :=
  constraintsHoldFlat_of_sourceRows ha hm hrec resolve env outs heqs
    (lookupRows_of_agree ha hm env outs hlookups)

/-! ## The Clean side -/

variable {Input Output : TypeMap} [ProvableType Input] [ProvableType Output]

/-- Reconstruct a circuit's typed output from the emitted component's ordered
`@out0` through `@out{size Output - 1}` assignment. -/
def moduleOutput (outs : Nat → F) : Output F :=
  fromElements (Vector.mapRange (size Output) outs)

/-- G9's output equalities identify the emitted component's typed `@out{j}`
assignment with evaluation of the Clean circuit's output expressions.

This is the output conjunct of `eqs_iff_of_agree`, kept as a named theorem so
the soundness chain cannot silently discard it while proving only the internal
Clean output. -/
theorem moduleOutput_eq_of_agree {cfg : Config} {c : FormalCircuit F Input Output}
    {m : Module} {C : ConstraintSet F}
    (ha : agree cfg (Compilable.source c) m = true)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0) :
    moduleOutput (Output := Output) outs =
      eval env (c.output (varFromOffset Input 0) (size Input)) := by
  unfold moduleOutput
  rw [ProvableType.fromElements_eq_iff]
  rw [Vector.ext_iff]
  intro i hi
  simp only [Vector.getElem_mapRange]
  rw [← ProvableType.getElem_eval_toElements]
  have hout := (ConstraintSet.eqs_iff_of_agree ha hm env outs).mp heqs |>.2
  have hall : ∀ x ∈ (Compilable.source c).outputs.toList.zipIdx,
      outs x.2 = x.1.eval env := by
    rintro ⟨e, j⟩ hj
    exact hout e j hj
  have hi' : i < (Compilable.source c).outputs.toList.length := by
    simp [Compilable.source, Source.ofFormalCircuit, hi]
  have hidx := (List.forall_mem_zipIdx').mp hall i hi'
  have hcoutput : (c.main (varFromOffset Input 0)).output (size Input) =
      c.output (varFromOffset Input 0) (size Input) := by
    exact c.elaborated.output_eq _ _
  calc
    outs i = Expression.eval env
        (toElements (M := Output)
          ((c.main (varFromOffset Input 0)).output (size Input)))[i] := by
      simp [Compilable.source, Source.ofFormalCircuit] at hidx
      exact hidx
    _ = Expression.eval env
        (toElements (M := Output)
          (c.output (varFromOffset Input 0) (size Input)))[i] := by
      rw [hcoutput]

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

/-- Successful checked compilation pins the typed module output directly to the
Clean output expressions. This needs equality satisfaction, but no lookup or
gadget-assumption premise. -/
theorem moduleOutput_eq_of_compile [CanonicalRepr F] {cfg : CertifiedConfig F}
    {c : FormalCircuit F Input Output} {m : Module} {C : ConstraintSet F}
    (hcompile : compile cfg c = .ok m)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0) :
    moduleOutput (Output := Output) outs =
      eval env (c.output (varFromOffset Input 0) (size Input)) :=
  moduleOutput_eq_of_agree (constraintsAgree_of_compileSourceVerified hcompile)
    hm env outs heqs

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
supported checked circuit entry point, and it takes a `CertifiedConfig`, so a
table cannot reach that path without its certificate. -/
theorem spec_of_compile [CanonicalRepr F] {cfg : CertifiedConfig F}
    {c : FormalCircuit F Input Output} {m : Module} {C : ConstraintSet F} {r : Recognized}
    (hcompile : compile cfg c = .ok m)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (hrec : recognize cfg.toConfig (Compilable.source (F := F) c) = .ok r)
    (resolve : ∀ l ∈ FlatOperation.lookups (Compilable.source (F := F) c).operations,
      ∃ ct ∈ cfg.tables, ∃ entry : Vector (Expression F) ct.table.arity,
        l = ⟨ct.table, entry⟩)
    (hnoint : ((c.main (varFromOffset Input 0)).operations (size Input)).interactions = [])
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : C.LookupRowsHold env outs)
    (input : Input F)
    (hinput : eval env (varFromOffset Input 0 : Var Input F) = input)
    (hassm : c.Assumptions input) :
    c.Spec input (moduleOutput (Output := Output) outs) := by
  rw [moduleOutput_eq_of_compile hcompile hm env outs heqs]
  exact spec_of_constraintsHoldFlat c env
    (constraintsHoldFlat_of_emitted (constraintsAgree_of_compileSourceVerified hcompile)
      hm hrec resolve env outs heqs hlookups)
    hnoint input hinput hassm

/-- Compatibility form of `spec_of_compile` for a caller that already states
lookup satisfaction over the source operations. Unlike `spec_of_compile`, this
theorem does not claim that premise was obtained from `C.lookups`. -/
theorem spec_of_compile_sourceRows [CanonicalRepr F] {cfg : CertifiedConfig F}
    {c : FormalCircuit F Input Output} {m : Module} {C : ConstraintSet F} {r : Recognized}
    (hcompile : compile cfg c = .ok m)
    (hm : ofModule (F := F) (Ty.felt cfg.field.name) m = some C)
    (hrec : recognize cfg.toConfig (Compilable.source (F := F) c) = .ok r)
    (resolve : ∀ l ∈ FlatOperation.lookups (Compilable.source (F := F) c).operations,
      ∃ ct ∈ cfg.tables, ∃ entry : Vector (Expression F) ct.table.arity,
        l = ⟨ct.table, entry⟩)
    (hnoint : ((c.main (varFromOffset Input 0)).operations (size Input)).interactions = [])
    (env : Environment F) (outs : Nat → F)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups (Compilable.source (F := F) c).operations,
      ∀ ct ∈ cfg.tables, ∀ entry : Vector (Expression F) ct.table.arity,
        l = ⟨ct.table, entry⟩ →
          ∃ values ∈ ct.exported.rows,
            values.map FiniteField.fromNat = (entry.map env).toArray)
    (input : Input F)
    (hinput : eval env (varFromOffset Input 0 : Var Input F) = input)
    (hassm : c.Assumptions input) :
    c.Spec input (moduleOutput (Output := Output) outs) := by
  rw [moduleOutput_eq_of_compile hcompile hm env outs heqs]
  exact spec_of_constraintsHoldFlat c env
    (constraintsHoldFlat_of_sourceRows (constraintsAgree_of_compileSourceVerified hcompile)
      hm hrec resolve env outs heqs hlookups)
    hnoint input hinput hassm

end LLZK
