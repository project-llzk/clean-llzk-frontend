import Clean.Backend.LLZK.Test.Soundness
import Clean.Backend.LLZK.Test.Lookups
import Clean.Backend.LLZK.Print

-- Release-audit theorem closure after the renderer/member-layout repair and
-- removal of the unused lower_spec fragment.
#print axioms LLZK.CanonicalRepr.val_natCast
#print axioms LLZK.WExpr.eval_lt_upperBound
#print axioms LLZK.WExpr.eval_bitsOf
#print axioms LLZK.WExpr.eval_ofWitgen
#print axioms LLZK.ofStatic_certifies
#print axioms LLZK.byteXorTable_certifies
#print axioms LLZK.ConstraintSet.eqs_iff_of_agree
#print axioms LLZK.ConstraintSet.lookupRows_of_agree
#print axioms LLZK.spec_of_compile
#print axioms LLZK.Module.render_semanticSurface
#print axioms LLZK.WitnessSet.CopyCanon.step_preserves
#print axioms LLZK.WitnessSet.CopyCanon.run_preserves

-- Concrete headline examples deliberately include their existing
-- native_decide/bv_decide facts; this records the exact trusted closure.
#print axioms LLZK.Test.Soundness.add8_spec_of_compile
#print axioms LLZK.Test.Soundness.and8_spec_of_compile
