import Clean.Backend.LLZK.Test.Coverage

-- Phase B extends this source-side theorem with literal-modulo and common
-- XOR/OR power-of-two cases. It must remain independent of circuit assumptions
-- and constraints.
#print axioms LLZK.WExpr.eval_lt_upperBound

-- The independent @compute reader still proves the complete lowered witness
-- expression means what Clean's witness IR means.
#print axioms LLZK.WExpr.eval_ofWitgen

-- G9 remains a precondition of the verified compile entry point after the
-- accepted witness language grows.
#print axioms LLZK.witnessAgree_of_compileSourceVerified
