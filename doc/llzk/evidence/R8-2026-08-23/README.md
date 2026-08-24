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
The later `r8-fresh-recovery-root` session was interrupted after leaving two
uncommitted optimizer-discriminator files. On 2026-08-24 its transcript was
confirmed aborted, its exact opaque lock owner was inspected, and the tree was
reclaimed with the documented compare-and-displace
`reclaim --from r8-fresh-recovery-root` path. The recovered diff was preserved
by hashes and independently reviewed before any edit; it was not assumed
correct.

```text
70075e4923db74f750ead5d8cd33481fb0d1ce8cc3373bad8aa2ec2c3b1a9977  scripts/llzk/lib.sh
6bc00eb5a63a1af4a11910fe7100178ab3ae1e83cbe46ab196fd4c68b2d4040a  scripts/llzk/test-scripts.sh
```

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
- `require_llzk_opt_discriminates` exercised only plain `llzk-opt`. A wrapper
  could delegate plain verification honestly while returning success only for
  `--verify-roundtrip` or `--llzk-product-program`, making G4 or G10a green
  without running the flagged operation. The first interrupted repair caught
  unconditional flagged success but still accepted a wrapper which merely
  stripped `--verify-roundtrip` and delegated to plain verification.

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

That module-output and claim repair was sealed at
`4248ddfcb58537c32b633687d1e1ba2a24fddd10`. The recovered flag-discriminator
repair was then independently falsified and strengthened before its own clean
seal `1e022fc495ff9297d05df0ef76ef0d22dc9df9fd`:

- G3, G4, and G10a now exercise their exact command families rather than
  inheriting the plain verifier's discrimination;
- a plain-valid/current-roundtrip-negative SMT parser/printer canary detects a
  globally stripped or ignored `--verify-roundtrip` flag, while active gate
  documentation states the finite-public-canary and immutable-tool-provenance
  boundary explicitly;
- the product positive must materialize `@product` IR with both compute and
  constraint provenance, and a non-`Main` module must survive plain verification
  and full inlining before the product pass rejects it;
- G11 independently rejects the original flag-selective wrappers, a no-op
  round-trip flag, a product no-op, and a product shim which fabricates the
  positive markers but accepts the wrong root.

Focused checks completed before the clean seal:

```text
lake build --wfail Clean                              PASS
lake build --wfail Clean.Backend.LLZK.Test.Soundness  PASS
lake env lean doc/llzk/evidence/R8-2026-08-23/module-output-probe.lean  PASS
bash scripts/llzk/test-scripts.sh                     PASS: 177 error paths
```

Those are the focused results before `4248ddfc`; the 177 count is historical,
not the recovered flag repair's result. The strengthened flag repair's frozen
pre-seal diff passed:

```text
bash -n scripts/llzk/lib.sh scripts/llzk/test-scripts.sh  PASS
git diff --check                                          PASS
```

After seal, the exact clean `1e022fc4` passed independently:

```text
git show --check --oneline 1e022fc4                       PASS
bash scripts/llzk/test-scripts.sh                         PASS: 181 error paths
require_llzk_opt_discriminates, accepted LLZK pin         PASS
require_llzk_opt_discriminates, checked LLZK main         PASS
```

The exact original G4 and G10a wrappers were first shown green against the
vulnerable `4248ddfc` helper and against inputs the real tool rejected, then
shown red against `1e022fc4`. A stronger wrapper which removed only
`--verify-roundtrip` while delegating all remaining arguments to the accepted
real tool was also red on the repaired helper. Two independent pre-commit
reviewers returned GO; a separate matrix reviewer confirmed all 17 corpus
artifacts and both renderer fixtures unconditionally reach G3, G4, and G10.

The accepted-pin G0-G12 matrix also passed on exact clean `1e022fc4`: 17 corpus
modules, 67 vectors, both backends of the pinned LLZK witness tool and both
output scopes, two renderer fixtures, 19/19 product admissions, exact SMT split
10/9, and 181 G11 paths. This was repair evidence, not the final
replacement-candidate matrix. The R8 documentation lane then found and required
the public-reading-path and live evidence repairs in this commit.

The raw nine-declaration output is captured in `axioms.txt`.
`moduleOutput_eq_of_compile` depends only on `propext`, `Classical.choice`, and
`Quot.sound`. The concrete wrappers retain their previously documented
Babybear/native proof facts; no printed closure contains `sorryAx`.

This file does not claim a replacement-candidate R8 pass and does not authorize
publication. After this evidence closure is sealed, its exact clean candidate
must pass both LLZK toolchain matrices and a full frozen-tree R8 review restarted
from the beginning before either an R8 pass or publication can be claimed.
