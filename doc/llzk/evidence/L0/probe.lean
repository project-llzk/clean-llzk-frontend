import Clean.Backend.LLZK.Test.Soundness
import Clean.Backend.LLZK.Test.Lookups
import Clean.Backend.LLZK.Print
import Clean.Backend.LLZK.WitnessCheck

-- L0 checks the unchanged frontend theorem closure after both tool matrices.
#print axioms LLZK.spec_of_compile
#print axioms LLZK.ofSource_lookups_iff
#print axioms LLZK.canonical_of_recognize
#print axioms LLZK.certified_membership
#print axioms LLZK.registryOk_of_recognize
#print axioms LLZK.size_eq_of_recognize
#print axioms LLZK.WExpr.eval_ofWitgen
#print axioms LLZK.Module.render_constraintSurface
#print axioms LLZK.WitnessSet.CopyCanon.step_preserves
#print axioms LLZK.WitnessSet.CopyCanon.run_preserves

-- These concrete examples deliberately include the two native_decide prime facts.
#print axioms LLZK.Test.Soundness.add8_spec_of_compile
#print axioms LLZK.Test.Lookups.add8_lookup_iff
