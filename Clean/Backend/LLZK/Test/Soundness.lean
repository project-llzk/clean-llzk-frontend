import Clean.Backend.LLZK.Soundness
import Clean.Backend.LLZK.Test.Lookups

/-!
# GAPS §3, instantiated at `Addition8FullCarry`

`Soundness.lean` has the chain. This applies it to the gadget Stage 1 was built
around, discharging everything about *this circuit* by proof and leaving only
facts about *this compile run*.

Discharged here, by unfolding the gadget's own operations:

* `resolve` — every lookup is into `Gadgets.ByteTable` (`Test/Lookups.lean`);
* `hnoint` — the circuit has no channel interactions, so
  `Operations.FullGuarantees` is vacuous and Clean's `can_replace_soundness`
  applies.

Left as hypotheses, and they are all of the form "this run of the compiler
succeeded": `compile … = .ok m`, `ofModule m = some C`, and `recognize … = .ok r`.
None of them reduces in the kernel — the operation list carries `Expression`s and
`Fact` instances — so they are checked rather than `rfl`'d, which is the same
check gate G1 runs: two by `#guard` below (`compile … isSome`,
`recognize … isOk`), and `ofModule m = some C` entailed by the first, because a
successful `compile` has evaluated `agree`, which requires `ofModule` to return
`some` (R7-15 — an earlier version of this comment said all three were
`#guard`ed). Closing them with `native_decide` would trade a checked fact for a
trusted one; see `GAPS.md` item 8.
-/

namespace LLZK.Test.Soundness

open LLZK LLZK.Examples LLZK.Test.Lookups

abbrev Bab := F pBabybear

private abbrev add8 : FormalCircuit Bab Gadgets.Addition8FullCarry.Inputs
    Gadgets.Addition8FullCarry.Outputs :=
  Gadgets.Addition8FullCarry.circuit (p := pBabybear)

-- The three facts about this compile run that the theorem below assumes. Same
-- checks as G1 and the corpus; the corpus additionally feeds the module to
-- llzk-opt and both witgen backends.
#guard (compile withBytes add8).toOption.isSome
#guard (recognize withBytes.toConfig (Compilable.source add8)).isOk

/-- **`Addition8FullCarry` performs no channel interactions.**

Which is why `Operations.FullGuarantees` is free for it, and hence why Clean's
`can_replace_soundness` applies with no side condition left over. True of
everything this backend accepts — `Analyze.recognizeOperation` refuses
`.interact` by name — but proved here for the concrete gadget rather than
assumed. -/
theorem add8_no_interactions :
    ((add8.main (varFromOffset Gadgets.Addition8FullCarry.Inputs 0)).operations
      (size Gadgets.Addition8FullCarry.Inputs)).interactions = [] := by
  simp [circuit_norm, Gadgets.Addition8FullCarry.circuit, Gadgets.Addition8FullCarry.main,
    Operations.interactions, FormalAssertion.toSubcircuit, FlatOperation.interactions]

/-- **The emitted module's constraints imply `Addition8FullCarry`'s `Spec`.**

`GAPS.md` §3 for the corpus's headline circuit. Read it as: take any assignment
of the emitted component's cells (`env` for the circuit variables, `outs` for the
`@out{j}` members D008 adds) that satisfies every polynomial the reader extracts
from `@constrain` and every lookup it extracts, assume the gadget's own
`Assumptions` of the input; then the gadget's own `Spec` holds of that input and
the corresponding output.

Everything about the *circuit* is discharged. What remains hypothetical is this
compile run, and D017 — that the emitted text means what the reader reads. -/
theorem add8_spec_of_compile {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytes add8 = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytes.field.name) m = some C)
    (hrec : recognize withBytes.toConfig (Compilable.source add8) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : C.LookupRowsHold env outs)
    (input : Gadgets.Addition8FullCarry.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.Addition8FullCarry.Inputs 0 :
        Var Gadgets.Addition8FullCarry.Inputs Bab) = input)
    (hassm : add8.Assumptions input) :
    add8.Spec input
      (eval env (add8.output (varFromOffset Gadgets.Addition8FullCarry.Inputs 0)
        (size Gadgets.Addition8FullCarry.Inputs))) :=
  spec_of_compile hcompile hm hrec add8_resolve add8_no_interactions env outs heqs hlookups
    input hinput hassm

/-- The same, with the lookup hypothesis in Clean's own form.

Sometimes the more useful shape: `add8_lookup_iff` converts between the two, and
this records that the conversion is available rather than making every caller
find it. -/
theorem add8_spec_of_compile' {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytes add8 = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytes.field.name) m = some C)
    (hrec : recognize withBytes.toConfig (Compilable.source add8) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups (Compilable.source add8).operations, l.Contains env)
    (input : Gadgets.Addition8FullCarry.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.Addition8FullCarry.Inputs 0 :
        Var Gadgets.Addition8FullCarry.Inputs Bab) = input)
    (hassm : add8.Assumptions input) :
    add8.Spec input
      (eval env (add8.output (varFromOffset Gadgets.Addition8FullCarry.Inputs 0)
        (size Gadgets.Addition8FullCarry.Inputs))) :=
  spec_of_compile_sourceRows hcompile hm hrec add8_resolve add8_no_interactions env outs heqs
    ((add8_lookup_iff hrec env).mp hlookups) input hinput hassm

/-! ## S28: the same chain instantiated at three-column `And8` -/

private abbrev and8 : FormalCircuit Bab Gadgets.And.And8.Inputs field :=
  Gadgets.And.And8.circuit (p := pBabybear)

#guard (compile withBytesAndXor and8).toOption.isSome
#guard (recognize withBytesAndXor.toConfig (Compilable.source and8)).isOk

theorem and8_no_interactions :
    ((and8.main (varFromOffset Gadgets.And.And8.Inputs 0)).operations
      (size Gadgets.And.And8.Inputs)).interactions = [] := by
  simp [circuit_norm, Gadgets.And.And8.circuit, Gadgets.And.And8.main,
    Operations.interactions]

/-- **The emitted multi-column `@ByteXor` membership plus the emitted
equalities imply `And8.Spec`.** This is the generic lookup-to-`spec_of_compile`
chain instantiated at the capability S28 adds. -/
theorem and8_spec_of_compile {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytesAndXor and8 = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytesAndXor.field.name) m = some C)
    (hrec : recognize withBytesAndXor.toConfig (Compilable.source and8) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : C.LookupRowsHold env outs)
    (input : Gadgets.And.And8.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.And.And8.Inputs 0 : Var Gadgets.And.And8.Inputs Bab) = input)
    (hassm : and8.Assumptions input) :
    and8.Spec input
      (eval env (and8.output (varFromOffset Gadgets.And.And8.Inputs 0)
        (size Gadgets.And.And8.Inputs))) :=
  spec_of_compile hcompile hm hrec and8_resolve and8_no_interactions env outs heqs hlookups
    input hinput hassm

/-- The `And8` instantiation with its lookup premise in Clean's own form. -/
theorem and8_spec_of_compile' {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytesAndXor and8 = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytesAndXor.field.name) m = some C)
    (hrec : recognize withBytesAndXor.toConfig (Compilable.source and8) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups (Compilable.source and8).operations,
      l.Contains env)
    (input : Gadgets.And.And8.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.And.And8.Inputs 0 : Var Gadgets.And.And8.Inputs Bab) = input)
    (hassm : and8.Assumptions input) :
    and8.Spec input
      (eval env (and8.output (varFromOffset Gadgets.And.And8.Inputs 0)
        (size Gadgets.And.And8.Inputs))) :=
  spec_of_compile_sourceRows hcompile hm hrec and8_resolve and8_no_interactions env outs heqs
    ((and8_lookup_iff hrec env).mp hlookups) input hinput hassm

/-! ## S29: the four-limb Xor32 instantiation -/

private abbrev xor32 : FormalCircuit Bab Gadgets.Xor32.Inputs U32 :=
  Gadgets.Xor32.circuit (p := pBabybear)

#guard (compile withBytesAndXor xor32).toOption.isSome
#guard (recognize withBytesAndXor.toConfig (Compilable.source xor32)).isOk

theorem xor32_no_interactions :
    ((xor32.main (varFromOffset Gadgets.Xor32.Inputs 0)).operations
      (size Gadgets.Xor32.Inputs)).interactions = [] := by
  simp [circuit_norm, Gadgets.Xor32.circuit, Gadgets.Xor32.main,
    Operations.interactions]

/-- **The emitted four ByteXor membership rows plus output equalities imply
Xor32's own Spec under its normalized-byte assumptions.**

Planned compute-only vectors intentionally cannot invoke this theorem: `hassm`
is retained explicitly. The remaining compile/readback/recognition premises and
D017 boundary are the same as the existing Add8 and And8 instantiations. -/
theorem xor32_spec_of_compile {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytesAndXor xor32 = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytesAndXor.field.name) m = some C)
    (hrec : recognize withBytesAndXor.toConfig (Compilable.source xor32) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : C.LookupRowsHold env outs)
    (input : Gadgets.Xor32.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.Xor32.Inputs 0 : Var Gadgets.Xor32.Inputs Bab) = input)
    (hassm : xor32.Assumptions input) :
    xor32.Spec input
      (eval env (xor32.output (varFromOffset Gadgets.Xor32.Inputs 0)
        (size Gadgets.Xor32.Inputs))) :=
  spec_of_compile hcompile hm hrec xor32_resolve xor32_no_interactions env outs heqs hlookups
    input hinput hassm

/-- The same Xor32 implication with lookup membership stated on Clean's source
rows; `xor32_lookup_iff` supplies the conversion to concrete certified registry rows. -/
theorem xor32_spec_of_compile' {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytesAndXor xor32 = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytesAndXor.field.name) m = some C)
    (hrec : recognize withBytesAndXor.toConfig (Compilable.source xor32) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups (Compilable.source xor32).operations,
      l.Contains env)
    (input : Gadgets.Xor32.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.Xor32.Inputs 0 : Var Gadgets.Xor32.Inputs Bab) = input)
    (hassm : xor32.Assumptions input) :
    xor32.Spec input
      (eval env (xor32.output (varFromOffset Gadgets.Xor32.Inputs 0)
        (size Gadgets.Xor32.Inputs))) :=
  spec_of_compile_sourceRows hcompile hm hrec xor32_resolve xor32_no_interactions env outs heqs
    ((xor32_lookup_iff hrec env).mp hlookups) input hinput hassm

/-! ## S29 HP: the composed BLAKE3.G 0/1/2/3 instantiation -/

private abbrev blake3g : FormalCircuit Bab Gadgets.BLAKE3.G.Inputs
    Gadgets.BLAKE3.BLAKE3State :=
  Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear)

#guard (compile withBytesAndXor blake3g).toOption.isSome
#guard (recognize withBytesAndXor.toConfig (Compilable.source blake3g)).isOk

private theorem addition32_subcircuit_no_interactions (n : Nat)
    (input : Var Gadgets.Addition32.Inputs Bab) :
    FlatOperation.interactions
      ((Gadgets.Addition32.circuit (p := pBabybear)).toSubcircuit n input).ops.toFlat = [] := by
  rcases input with ⟨x, y⟩
  simp [circuit_norm, FormalCircuit.toSubcircuit, Gadgets.Addition32.circuit,
    Gadgets.Addition32.main, Gadgets.Addition32Full.circuit,
    Gadgets.Addition32Full.main, Gadgets.Addition8FullCarry.main,
    FormalAssertion.toSubcircuit, FlatOperation.interactions]

private theorem xor32_subcircuit_no_interactions (n : Nat)
    (input : Var Gadgets.Xor32.Inputs Bab) :
    FlatOperation.interactions
      ((Gadgets.Xor32.circuit (p := pBabybear)).toSubcircuit n input).ops.toFlat = [] := by
  rcases input with ⟨x, y⟩
  simp [circuit_norm, FormalCircuit.toSubcircuit, Gadgets.Xor32.circuit,
    Gadgets.Xor32.main, FlatOperation.interactions]

private theorem byteDecomposition_main_no_interactions (offset : Fin 8)
    (n : Nat) (input : Expression Bab) :
    Operations.interactions ((Gadgets.ByteDecomposition.main offset input).operations n) = [] := by
  simp [circuit_norm, Gadgets.ByteDecomposition.main, Gadgets.Equality.circuit,
    Gadgets.Equality.main, FormalAssertion.toSubcircuit]

private theorem byteDecomposition_circuit_main_no_interactions (offset : Fin 8)
    (n : Nat) (input : Expression Bab) :
    Operations.interactions
      (((Gadgets.ByteDecomposition.circuit offset (p := pBabybear)).main input).operations n) =
      [] := by
  exact byteDecomposition_main_no_interactions offset n input

private theorem rotation32_subcircuit_no_interactions (offset : Fin 32) (n : Nat)
    (input : Var U32 Bab) :
    FlatOperation.interactions
      ((Gadgets.Rotation32.circuit offset (p := pBabybear)).toSubcircuit n input).ops.toFlat =
      [] := by
  rcases input with ⟨x0, x1, x2, x3⟩
  fin_cases offset <;>
    simp [circuit_norm, FormalCircuit.toSubcircuit, Gadgets.Rotation32.circuit,
      Gadgets.Rotation32.main, Gadgets.Rotation32Bytes.circuit,
      Gadgets.Rotation32Bytes.main, Gadgets.Rotation32Bits.circuit,
      Gadgets.Rotation32Bits.main, byteDecomposition_circuit_main_no_interactions]

/-- The exact composed `G 0 1 2 3` circuit performs no channel interactions. -/
theorem blake3g_no_interactions :
    ((blake3g.main (varFromOffset Gadgets.BLAKE3.G.Inputs 0)).operations
      (size Gadgets.BLAKE3.G.Inputs)).interactions = [] := by
  simp [circuit_norm, Gadgets.BLAKE3.G.circuit, Gadgets.BLAKE3.G.main,
    Operations.interactions, addition32_subcircuit_no_interactions,
    xor32_subcircuit_no_interactions, rotation32_subcircuit_no_interactions]

/-- The emitted equalities and the two concrete certified lookup arrays imply
the exact `G 0 1 2 3` Clean specification under its explicit normalization
assumptions. -/
theorem blake3g_spec_of_compile {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytesAndXor blake3g = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytesAndXor.field.name) m = some C)
    (hrec : recognize withBytesAndXor.toConfig (Compilable.source blake3g) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : C.LookupRowsHold env outs)
    (input : Gadgets.BLAKE3.G.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.BLAKE3.G.Inputs 0 : Var Gadgets.BLAKE3.G.Inputs Bab) = input)
    (hassm : blake3g.Assumptions input) :
    blake3g.Spec input
      (eval env (blake3g.output (varFromOffset Gadgets.BLAKE3.G.Inputs 0)
        (size Gadgets.BLAKE3.G.Inputs))) :=
  spec_of_compile hcompile hm hrec blake3g_resolve blake3g_no_interactions env outs heqs
    hlookups input hinput hassm

/-- The same `G 0 1 2 3` implication with lookup membership stated over the
Clean source rows; `blake3g_lookup_iff` supplies the heterogeneous conversion. -/
theorem blake3g_spec_of_compile' {m : Module} {C : ConstraintSet Bab} {r : Recognized}
    (hcompile : compile withBytesAndXor blake3g = .ok m)
    (hm : ConstraintSet.ofModule (F := Bab) (Ty.felt withBytesAndXor.field.name) m = some C)
    (hrec : recognize withBytesAndXor.toConfig (Compilable.source blake3g) = .ok r)
    (env : Environment Bab) (outs : Nat → Bab)
    (heqs : ∀ p ∈ C.eqs, Poly.eval (assign env outs) p = 0)
    (hlookups : ∀ l ∈ FlatOperation.lookups (Compilable.source blake3g).operations,
      l.Contains env)
    (input : Gadgets.BLAKE3.G.Inputs Bab)
    (hinput : eval env
      (varFromOffset Gadgets.BLAKE3.G.Inputs 0 : Var Gadgets.BLAKE3.G.Inputs Bab) = input)
    (hassm : blake3g.Assumptions input) :
    blake3g.Spec input
      (eval env (blake3g.output (varFromOffset Gadgets.BLAKE3.G.Inputs 0)
        (size Gadgets.BLAKE3.G.Inputs))) :=
  spec_of_compile_sourceRows hcompile hm hrec blake3g_resolve blake3g_no_interactions env outs
    heqs ((blake3g_lookup_iff hrec env).mp hlookups) input hinput hassm

end LLZK.Test.Soundness
