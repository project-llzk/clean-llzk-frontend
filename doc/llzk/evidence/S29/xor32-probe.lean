import Clean.Backend.LLZK.Test.Soundness

-- The primary claim consumes lookup rows read from the emitted typed module.
#print axioms LLZK.Test.Soundness.xor32_spec_of_compile

-- The source-row convenience theorem must not introduce a stronger trust base.
#print axioms LLZK.Test.Soundness.xor32_spec_of_compile'

-- Concrete table identity is proved from Xor32's four source lookups.
#print axioms LLZK.Test.Lookups.xor32_lookups_are_byteXor
#print axioms LLZK.Test.Lookups.xor32_resolve
