# R8 frozen-candidate review and repair

Status: **in progress; no candidate has passed R8**

The first frozen candidate was documentation closure commit `c60d8363`, a
direct child of S29 implementation commit `a3299ca0`. Independent soundness,
process/evidence, and control reviewers rejected it on 2026-08-23. Its detached
first gate attempt stopped at G1 because that fresh worktree lacked the local
Lake package cache and network access; this was an environmental stop, not a
candidate gate verdict.

The main worktree initially still carried the earlier
`s29-blake3g-promotion` lock identity. On 2026-08-23 that holder explicitly
released the lock; the repair then claimed it as
`r8-repair-20260823-root`. No reclaim or silent ownership displacement occurred.

Confirmed review findings were:

- `spec_of_compile` and its concrete wrappers concluded `Spec` for Clean's
  internally recomputed output expression. Although emitted output equalities
  were premises, the theorem discarded that conjunct instead of concluding for
  the module assignment's ordered public `@out{j}` values.
- the executable banner called the two modes of one LLZK witness executable
  independent backends;
- reproduction snippets acquired the worktree lock without reliably releasing
  it, and one gate command omitted the lock protocol;
- several active comments and status pages overstated lower-level public-entry
  confinement, corpus/source scope, or R8 progress;
- a stale gap bullet still claimed extra unwritten members could pass both G9
  readers after exact member-layout validation had closed that blind spot.

The replacement repair, while live before its clean seal:

- defines `moduleOutput` from `fromElements (Vector.mapRange ... outs)` and
  proves `moduleOutput_eq_of_compile` from the output-equality half of G9;
- changes both generic soundness theorem forms and all Add8, And8, Xor32, and
  BLAKE3.G wrappers to conclude `Spec` for that reconstructed module output;
- adds `module-output-probe.lean`, whose four exact application examples spell
  the reconstruction without hiding it behind the helper and whose axiom probe
  includes all eight primary/source-row wrappers;
- repairs the banner, reproduction lifecycle, active scope terminology, and
  dated audit/status records without rewriting historical S29 probe files or
  their recorded hashes.

Focused checks completed before the clean seal:

```text
lake build --wfail Clean                              PASS
lake build --wfail Clean.Backend.LLZK.Test.Soundness  PASS
lake env lean doc/llzk/evidence/R8-2026-08-23/module-output-probe.lean  PASS
bash scripts/llzk/test-scripts.sh                     PASS: 177 error paths
```

The raw nine-declaration output is captured in `axioms.txt`.
`moduleOutput_eq_of_compile` depends only on `propext`, `Classical.choice`, and
`Quot.sound`. The concrete wrappers retain their previously documented
Babybear/native proof facts; no printed closure contains `sorryAx`.

This file does not claim full G0-G12 success or an R8 pass. The resulting clean
repair commit still must pass both exact LLZK toolchain matrices and restart the
frozen-tree R8 review from the beginning before either claim can be made.
