# S29 bootstrap and recovery

- Audited frontend branch base: `9b46264c59ed69af24817cb4b2cfdb7ebcfb4629`.
- Fully gated substantive audit tree: `7c567f5451c2e40b7be88e96d8a519a7bf82495e`.
- Upstream Clean base: `0e53b9f2d05f06defa2aa0a859f549b611583f10`.
- Accepted LLZK pin: `25fb3740ea3465c9129a06289297bb4f0554b7a5`.
- Checked LLZK main: `b5c110d1088e93d6786f66ec1e155be87bae755f`.

Bootstrap found local integration at stale R7 tip `97390fac`, 102 commits
behind the audited frontend, while `CURRENT.md` named an evidence path rather
than a commit. Following `ORCHESTRATION.md` section 4.1, feature work paused and
local `clean-to-llzk/integration` was fast-forwarded to `9b46264c`. No remote
ref, PR, issue, or organization state changed.

Three independent adversarial reviewers were assigned before design freeze:

1. semantic/proof soundness of modulo and XOR/OR bounds;
2. Clean-overlay, pin, evidence, and R8 process integrity;
3. red controls, corpus vectors, concrete soundness instantiations, and
   false-green resistance.

Confirmed bootstrap findings incorporated into D035 and the S29 packet include:

- a narrow modulo result must not hide either felt reduction or u64 wrap in its
  numerator, and those failure mechanisms need separate red fixtures;
- generic modulo does not repair wide-field `.val` truncation;
- modulo needs the exact `min` bound and XOR/OR a common power-of-two ceiling;
- the Clean change needs an exact upstream-based overlay and atomic pin adoption,
  never a G0 allowlist;
- G9 needs wrong-divisor, wrong-operand, and XOR/OR mutation controls;
- out-of-assumption Xor32 vectors must independently discriminate narrowing on
  every limb;
- wide public outputs need first/middle/last harness mutations;
- promoted examples need hard-coded public references independent of their
  Clean-derived witnesses, with reproducible non-Clean oracle provenance;
- every cross-reader mutation needs green self-baselines for both sources before
  the cross-comparison may count as red;
- BLAKE3.G lookup resolution must cover both Byte and ByteXor tables;
- `GATES.md` still said 53 rather than the audited 54 G11 paths.

No feature source or lowering code changed during bootstrap. The independently
reviewed decision and session packet is commit
`d0eed96074d05ccdd0f628eee66e7a2f3d0f0463`.
