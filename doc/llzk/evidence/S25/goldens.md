# S25 golden-output result

No accepted emitted LLZK text changed.

- The compatibility diff from `805f2a07` to implementation commit `6ccca6f8`
  changes no accepted LLZK golden block and does not change
  `doc/llzk/EXAMPLES.md`.
- G1 rebuilt the exact `#guard_msgs` goldens and required the generated showcase
  to be byte-identical to the checked-in page.
- G2 emitted the same 12-circuit, 33-vector, two-renderer-fixture corpus; G3 and
  G4 accepted and round-tripped all 14 modules.

The only expected textual test changes are rejection diagnostics. They rename
the old `NExpr`/`ofNat` language to `U64Expr`/`ofU64` and add exact diagnostics
for the five newly reachable upstream surfaces: `letU`, `envRange`, `bitsOf`,
`BExpr.flt`, and `BExpr.bit`. No accepted golden was regenerated to make the
bump pass.
