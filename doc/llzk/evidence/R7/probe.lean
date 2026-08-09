import Clean.Backend.LLZK.Test.Soundness
import Clean.Backend.LLZK.Test.Lookups

-- P2: axiom hygiene. EXPECT generic theorems = [propext, Classical.choice, Quot.sound] only.
#print axioms LLZK.spec_of_compile
#print axioms LLZK.ofSource_lookups_iff
#print axioms LLZK.canonical_of_recognize
#print axioms LLZK.certified_membership
#print axioms LLZK.registryOk_of_recognize
#print axioms LLZK.size_eq_of_recognize

-- Concrete instantiations: EXPECT + Lean.ofReduceBool/trustCompiler via native_decide primes.
-- ANY sorryAx = red flag (Circomlib's sorry in the closure).
#print axioms LLZK.Test.Soundness.add8_spec_of_compile
#print axioms LLZK.Test.Lookups.add8_lookup_iff

-- P3: non-vacuity — ofModule succeeds on the compiled module, C.eqs non-empty.
#eval match LLZK.compile LLZK.Examples.withBytes
        (Gadgets.Addition8FullCarry.circuit (p := pBabybear)) with
  | .ok m => toString ((LLZK.ConstraintSet.ofModule (F := F pBabybear)
      (LLZK.Ty.felt LLZK.Examples.withBytes.field.name) m).map
        fun (C : LLZK.ConstraintSet (F pBabybear)) =>
          (C.eqs.length, C.lookups.length, C.globals.length))
  | .error _ => "refused"

-- P4: F1 witness — CertifiedTable imposes no name tie (this elaborating = the gap exists).
example (e : LLZK.ExportTable) (t : Table (F pBabybear) field)
    (h : e.Certifies t) : LLZK.CertifiedTable (F pBabybear) := ⟨e, t, h⟩
