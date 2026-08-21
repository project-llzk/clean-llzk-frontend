import Clean.Backend.LLZK.Showcase

/-!
# The public example table is backed by the conformance corpus

These guards make its denominator, ordering, vector count, source-agreement
count, and editorial coverage reviewed diffs. `e2e.sh` additionally regenerates
`doc/llzk/EXAMPLES.md` and requires byte equality.
-/

namespace LLZK.Test.Showcase

#guard Showcase.markdown.isOk
#guard Showcase.totalVectors == 45
#guard Showcase.sourceBacked == 8
#guard Corpus.corpus.size == 14
#guard Corpus.corpus.all fun entry => (Showcase.purpose entry.name).isSome
#guard Corpus.corpus.map (·.name) ==
  #[ "Multiply", "Decompose", "LowByte", "Bits8", "Addition8FullCarry", "Passthrough", "ConstOut", "CopyCell"
   , "Square_babybear", "Square_mersenne31", "Square_koalabear", "Square_goldilocks"
   , "Square_bn254", "Square_grumpkin" ]

end LLZK.Test.Showcase
