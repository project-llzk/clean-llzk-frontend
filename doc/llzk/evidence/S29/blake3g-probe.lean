import Clean.Backend.LLZK.Test.Soundness

open LLZK LLZK.Examples

abbrev Bab := F pBabybear

private abbrev blake3g : FormalCircuit Bab Gadgets.BLAKE3.G.Inputs
    Gadgets.BLAKE3.BLAKE3State :=
  Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear)

#guard (compile withBytesAndXor blake3g).toOption.isSome
#guard (recognize withBytesAndXor.toConfig (Compilable.source blake3g)).isOk

-- Pin the primary theorem's exact module-reader premise, explicit source
-- assumptions, and exact G 0/1/2/3 conclusion. This is an application, not a
-- declaration-existence check, so dropping `hassm` or weakening `Spec` is red.
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
      (eval env (blake3g.output (varFromOffset Gadgets.BLAKE3.G.Inputs 0)
        (size Gadgets.BLAKE3.G.Inputs))) :=
  LLZK.Test.Soundness.blake3g_spec_of_compile hcompile hm hrec env outs heqs hlookups
    input hinput hassm

-- Pin the convenience theorem separately: it consumes Clean source lookup
-- membership, while the primary theorem above consumes module-reader rows.
example {m : Module} {C : ConstraintSet Bab} {r : Recognized}
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
  LLZK.Test.Soundness.blake3g_spec_of_compile' hcompile hm hrec env outs heqs hlookups
    input hinput hassm

#print axioms LLZK.Test.Soundness.blake3g_spec_of_compile
#print axioms LLZK.Test.Soundness.blake3g_spec_of_compile'
#print axioms LLZK.Test.Soundness.blake3g_no_interactions
#print axioms LLZK.Test.Lookups.blake3g_lookups_are_bytes_or_byteXor
#print axioms LLZK.Test.Lookups.blake3g_resolve
#print axioms LLZK.Test.Lookups.blake3g_lookup_iff
