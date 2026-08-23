import Clean.Backend.LLZK.Test.Soundness

/-!
R8 repair probe: each primary concrete soundness theorem must elaborate at the
typed output reconstructed directly from the emitted component's ordered
`@out{j}` assignment. Writing `fromElements (Vector.mapRange ... outs)` here,
rather than the `moduleOutput` helper, makes that API boundary explicit. The
source-row compatibility forms are separately compiled at their explicit
`moduleOutput` conclusions in `Test/Soundness.lean` and included in the axiom
probe below.
-/

open LLZK LLZK.Examples

abbrev Bab := F pBabybear

private abbrev add8 : FormalCircuit Bab Gadgets.Addition8FullCarry.Inputs
    Gadgets.Addition8FullCarry.Outputs :=
  Gadgets.Addition8FullCarry.circuit (p := pBabybear)

private abbrev and8 : FormalCircuit Bab Gadgets.And.And8.Inputs field :=
  Gadgets.And.And8.circuit (p := pBabybear)

private abbrev xor32 : FormalCircuit Bab Gadgets.Xor32.Inputs U32 :=
  Gadgets.Xor32.circuit (p := pBabybear)

private abbrev blake3g : FormalCircuit Bab Gadgets.BLAKE3.G.Inputs
    Gadgets.BLAKE3.BLAKE3State :=
  Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear)

example {m : Module} {C : ConstraintSet Bab} {r : Recognized}
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
      (fromElements (M := Gadgets.Addition8FullCarry.Outputs)
        (Vector.mapRange (size Gadgets.Addition8FullCarry.Outputs) outs)) :=
  LLZK.Test.Soundness.add8_spec_of_compile hcompile hm hrec env outs heqs hlookups
    input hinput hassm

example {m : Module} {C : ConstraintSet Bab} {r : Recognized}
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
      (fromElements (M := field) (Vector.mapRange (size field) outs)) :=
  LLZK.Test.Soundness.and8_spec_of_compile hcompile hm hrec env outs heqs hlookups
    input hinput hassm

example {m : Module} {C : ConstraintSet Bab} {r : Recognized}
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
      (fromElements (M := U32) (Vector.mapRange (size U32) outs)) :=
  LLZK.Test.Soundness.xor32_spec_of_compile hcompile hm hrec env outs heqs hlookups
    input hinput hassm

example {m : Module} {C : ConstraintSet Bab} {r : Recognized}
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
      (fromElements (M := Gadgets.BLAKE3.BLAKE3State)
        (Vector.mapRange (size Gadgets.BLAKE3.BLAKE3State) outs)) :=
  LLZK.Test.Soundness.blake3g_spec_of_compile hcompile hm hrec env outs heqs hlookups
    input hinput hassm

#print axioms LLZK.moduleOutput_eq_of_compile
#print axioms LLZK.Test.Soundness.add8_spec_of_compile
#print axioms LLZK.Test.Soundness.add8_spec_of_compile'
#print axioms LLZK.Test.Soundness.and8_spec_of_compile
#print axioms LLZK.Test.Soundness.and8_spec_of_compile'
#print axioms LLZK.Test.Soundness.xor32_spec_of_compile
#print axioms LLZK.Test.Soundness.xor32_spec_of_compile'
#print axioms LLZK.Test.Soundness.blake3g_spec_of_compile
#print axioms LLZK.Test.Soundness.blake3g_spec_of_compile'
