# L0 preflight evidence

Date: 2026-08-21

Read-only GitHub API comparison:

```text
accepted  5db6f8f9baaa40787a1a40625796497445f2da36
candidate 25fb3740ea3465c9129a06289297bb4f0554b7a5
status    ahead
commits   25
files     193
all       +31,750 / -26,973
non-test  +3,921 / -1,305
```

Category counts:

```text
47  include/llzk + lib core files
10  tools/llzk-witgen files
 5  backends/smt files
34  other backend files
67  test + unittest files
```

Largest non-test changed files:

```text
994  backends/pcl/lib/Conversion/PCLLoweringPass.cpp
636  backends/r1cs/lib/r1cs/Target/R1CSBinary.cpp
580  lib/Transforms/LLZKPolyLoweringPass.cpp
262  tools/llzk-witgen/Wtns.cpp
224  lib/Dialect/Polymorphic/Transforms/FlatteningPass.cpp
198  lib/Dialect/POD/Transforms/PodToScalarPass.cpp
187  lib/Dialect/Polymorphic/Transforms/SharedImpl.cpp
163  lib/Transforms/LLZKRedundantReadAndWriteEliminationPass.cpp
```

Commit inventory:

```text
a85a47945716  Make specialization name encoding collision-safe (#633)
df44e8272df4  Fix poly lowering for non-Felt equalities (#663)
ace664581442  code cleanup and formatting (#674)
73933dad6136  Fix FileCheck generation for inline attributes (#672)
64efb3cafa1f  guard recursive purposeless constrain checks (#670)
caf8c88f519b  properly invalidate array aliases across dynamic/constant writes (#671)
57d7b9041f86  adding r1cs binary extractor (#537)
5e92d7242679  Assorted PCL backend bugfixes (#676)
e1996219abd1  r1cs lowering: fix invalid builder insertion point (#679)
67deb1ae3fd4  PCL: Add trim expression pass (#677)
ecfff280bf80  minor optimizations and cleanup in r1cs lowering (#681)
0d652966c80f  Cleanup poly lowering and change assertion failure to error (#678)
1b51a8b9abcc  Stubbed lowering mode for LLZK-to-PCL (#682)
9f3b2a6f835d  Split the slowest lit tests (#683)
c70f077b9e31  Preserve generated check segments (#685)
683c6d412922  Rename product fusion pass (#684)
4fe1538eb9e9  Preserve writes observed by dynamic array reads (#675)
5b9267feab75  modernize with matchAndRewrite + cleanup + optimization (#687)
8b5681bf74c3  Work around upstream remove-dead-values bug (#686)
a79a726f580d  clang-tidy cleanup
64ab72d1e303  Fix CMake when BUILD_TESTING=OFF (#690)
11b6c8336085  Reject unsupported zero-result ops in ZKLean conversion (#496)
d2c8ece96581  CI clang-format update (#692)
3cdaac215241  code style
25fb3740ea34  fix typo
```

Directly inspected patches:

- `Function/Ops.td`: adds `calleeIsInStruct`; no textual operation change.
- product pipeline: internal pass rename from fuse-product-loops to
  fuse-product-control-flow; public product-program pipeline remains.
- `WitgenDriver.cpp`: interpreter now honors the selected output scope rather
  than always collecting full witness output.
- `WitgenLowering.cpp`: entry construction now carries `OutputScope`; most other
  touched lines are cast modernization.
- `WitnessSelection.cpp`: adds R1CS witness selection for private main felts.
- `llzk-witgen.cpp`: adds WTNS output and its R1CS-specific output scope.
- SMT CF patch inspected here is refactoring; other SMT and poly-lowering files
  still require the actual G10b run.
- CMake patch repairs disabled-testing builds; `llzk-opt` registers the new PCL
  transform pass.

Live `main` was re-queried immediately before freezing this evidence and still
equaled the candidate SHA above. No LLZK repository, pin, Nix output, remote, or
GitHub setting was changed by the preflight.
