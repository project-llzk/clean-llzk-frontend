import Clean.Backend.LLZK.WitnessCheck

-- The source-side bound and meaning theorems added by S26.
#print axioms LLZK.WExpr.eval_lt_upperBound
#print axioms LLZK.WExpr.eval_ofWitgen
#print axioms LLZK.WExpr.eval_bitsOf

-- The new `FieldExpr.u64Bin` lowering remains inside the existing SSA theorem.
#print axioms LLZK.FieldExpr.lower_spec

-- G9 remains a precondition of the public verified compile entry point.
#print axioms LLZK.witnessAgree_of_compileSourceVerified
