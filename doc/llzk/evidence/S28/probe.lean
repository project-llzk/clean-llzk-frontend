import Clean.Backend.LLZK.Test.Soundness

-- Generic row/canonical-representation certificate chain.
#print axioms LLZK.canonicalRow_injective
#print axioms LLZK.ofStatic_certifies
#print axioms LLZK.certified_membership
#print axioms LLZK.ConstraintSet.lookupRows_of_agree

-- Concrete full-size certificate and protected rendered surface.
#print axioms LLZK.byteXorTable_certifies
#print axioms LLZK.Module.render_constraintSurface

-- The generic lookup chain is concretely instantiated at arity-three And8.
-- Its expected trusted closure includes the two existing native_decide prime
-- facts and And8's upstream bv_decide identity; no S28 theorem introduces one.
#print axioms LLZK.Test.Lookups.and8_lookup_iff
#print axioms LLZK.Test.Soundness.and8_spec_of_compile
