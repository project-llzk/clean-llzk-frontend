import Clean.Backend.LLZK.WitnessCheck

/-!
A7 theorem-closure probe.

The declaration below is the premise formerly justified only by inspecting the
mutable copy-canonicalisation loop. Its assumptions say exactly that the old
representatives and the newly defined witness cell have their intended values;
its conclusion says extending the map preserves that invariant everywhere.
-/

#print axioms LLZK.WitnessSet.CopyCanon.step_preserves
#print axioms LLZK.WitnessSet.CopyCanon.run_preserves
