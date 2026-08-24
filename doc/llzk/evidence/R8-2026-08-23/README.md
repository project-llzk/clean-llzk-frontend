# R8 frozen-candidate review and repair

Status: **R8 passed locally on code candidate `193ec342`; publication is not authorized**

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
- the later documentation closure still left a release-less contributor gate
  recipe and direct owner-file deletion advice active. More importantly,
  `reclaim --from` compared and replaced the owner in separate unsynchronized
  operations, so a new holder could arrive between them and be overwritten.
  Concurrent free-tree claims and release had the same race; release also let a
  non-holder remove a provably stale numeric record.

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
replacement-candidate matrix. An independent documentation audit then found
and required the public-reading-path and live evidence repairs in the next
seal.

Those documentation repairs were sealed at `beb2f54d22b5aa1fd29a2c74461489e11030ab20`.
Its exact clean accepted-pin matrix passed G0-G12 with the same 17/67/2,
19/19, 10/9, and 181 counts. This remains diagnostic evidence only: before a
checked-main matrix began, an independent attached-tree concurrency audit
rejected the candidate on the owner-record race and stale lifecycle text above.
The matrix log remained only in `/tmp`, so it is not durable acceptance
evidence and is not cited as such.

The transaction repair was sealed at
`4819f6edd040ede1f347a1853ee97df20eb6484c`. It serializes every cooperating
lock command on a separate persistent per-worktree `flock` guard, atomically
replaces complete three-line owner records, and requires exact owner identity
for every release. Six deterministic G11 controls queue claims, reclaim,
release, status, and require behind an externally held guard, make a failed
kernel lock preserve the owner byte-for-byte, and close the stale-numeric
release path. D037 records the platform prerequisite,
transaction/ownership distinction, and residual advisory bypasses.

Both exact LLZK matrices passed on clean `4819f6ed`, but R8 did not accept it.
The formal documentation/public-readiness lane found a live Plonky3 README link
to nonexistent `tests/clean_air.rs`, a test filter naming no current test, and a
placeholder URL. The same libtest substring-filter pattern was present in the
required CI job and exits zero on no matches. The independent evidence lane also
refused `/tmp`-only matrix and false-green records under `GATES.md`'s durability
rule. These were candidate findings, not waivers.

The non-vacuity repair was sealed as exact code candidate
`193ec342cb2aae9055c36f4f77d2a4fe23da7823`, the sole child of `4819f6ed`.
Its two-file diff points the README at `tests/fib_tests.rs`, removes the
placeholder, and makes the README and every Plonky3 CI group assert the exact
registered inventory and names before running the complete target with
`--include-ignored`. This closes zero-match, substring, wrong-target,
unexpected-count, and ignored-test greens. The exact candidate replay passed
one Fibonacci, two debug-negative, two release-negative, and two FemtoCairo
tests locally under Rust/Cargo 1.96.0. The workflow pins Rust 1.98.0; its hosted
organization run remains a publication-stage check, not a result claimed here.

Both full G0–G12 matrices then passed on exact clean `193ec342`: 187 G11 paths,
17 corpus modules, 67 vectors, both modes of the pinned witness executable and
both output scopes, two renderer fixtures, G9 on 11 source-backed modules with
six registry entries N/A, 19/19 product admissions, and exact SMT split 10/9.
Accepted-pin and checked-main raw transcripts are tracked here. Their only raw
differences are the two tool store paths and Lean's replay-progress counter;
after the complete recorded normalization they are byte-identical. The focused
soundness build, current module-output probe, exact G4/G10a vulnerable-parent
reproduction, and sealed Plonky3 block also pass with complete commands,
statuses, inputs, and outputs in [`FINAL-VERIFICATION.md`](FINAL-VERIFICATION.md).

The raw nine-declaration output is captured in `axioms.txt`.
`moduleOutput_eq_of_compile` depends only on `propext`, `Classical.choice`, and
`Quot.sound`. The concrete wrappers retain their previously documented
Babybear/native proof facts; no printed closure contains `sorryAx`.

Three independent lanes restarted from fresh detached clean worktree
`/tmp/clean-llzk-r8-193ec342-lanef`. They reviewed theorem/output soundness,
gate reachability and evidence, and public documentation/governance. Their blind
records preceded the first control-set opening on the prior frozen candidate;
the exact-`193ec342` restart re-audited the candidate and its delta with those
controls already known. All final candidate findings were repaired;
[`FORMAL-REVIEW.md`](FORMAL-REVIEW.md) records the final GO dispositions and
the corrected S4 boundary (a representable but untested zero-input checked
source), generic table-identity gap, and D017 limit.

This closes the local frozen-candidate R8 milestone on code candidate
`193ec342`. The later evidence/status commit is a documentation-only child and
is not retroactively described as the matrix-tested candidate. No branch was
pushed, no repository was created or transferred, and no organization setting
was changed. Publication and organization-repository CI remain a separate
explicitly authorized decision.
