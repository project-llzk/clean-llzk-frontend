# R8 replacement-candidate verification

Tested code candidate:
`193ec342cb2aae9055c36f4f77d2a4fe23da7823` (`193ec342`). Its sole parent is
transaction-lock candidate `4819f6edd040ede1f347a1853ee97df20eb6484c`.
The candidate commit changes exactly `.github/workflows/ci.yml` and
`backends/plonky3/readme.md`: 33 insertions and 9 deletions. The `Clean/`,
`scripts/llzk/`, Plonky3 source/test, and Cargo manifest/lock trees are
byte-identical to `4819f6ed`. `git status --short` was empty before and after
every candidate run.

This evidence is committed later as a documentation-only child. That child is
not relabelled as the matrix-tested code candidate. Publication, a push, and
organization-repository CI remain separate explicitly authorized actions.

## Full matrices

Both commands ran from `/home/alh/LLZK/clean-llzk-frontend` with the already
held `r8-replacement-recovery-root` owner. `set -o pipefail` made the captured
status the matrix status rather than `tee`'s status.

```bash
set -o pipefail
LLZK_SESSION=r8-replacement-recovery-root \
LLZK_OPT=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin/llzk-opt \
LLZK_WITGEN=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin/llzk-witgen \
bash scripts/llzk/e2e.sh 2>&1 | tee /tmp/r8-final-accepted-193ec342.log
# exit 0

LLZK_SESSION=r8-replacement-recovery-root \
LLZK_OPT=/nix/store/hvvbkw0afshj37zpiilw0jwxjxfad4p4-llzk-release-3.0.0/bin/llzk-opt \
LLZK_WITGEN=/nix/store/hvvbkw0afshj37zpiilw0jwxjxfad4p4-llzk-release-3.0.0/bin/llzk-witgen \
bash scripts/llzk/e2e.sh 2>&1 | tee /tmp/r8-final-main-193ec342.log
# exit 0
```

The first installation is accepted LLZK source
`25fb3740ea3465c9129a06289297bb4f0554b7a5`; the second is checked LLZK main
`b5c110d1088e93d6786f66ec1e155be87bae755f`. Both exact sibling tools report,
or inherit from their co-located optimizer, LLZK 3.0.0. The raw transcripts are
tracked as [`accepted-matrix.txt`](accepted-matrix.txt) and
[`checked-main-matrix.txt`](checked-main-matrix.txt).

| Transcript | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| accepted pin | `5636a864208468503bbb28a49aba9b1f971d956e40720f2b8530589cfecc421b` | 557 | 29953 |
| checked main | `fd7e77a0ee2114ba5bb360fc470f2d7e5dd807635aafe78a82555ad0c874daa2` | 557 | 29953 |

Independent mechanical audits found, in each transcript:

- exact G0 attribution to candidate `193ec342`, upstream Clean `0e53b9f2`,
  Clean overlay `3d086f32`, and Lean 4.32.2;
- G11 `PASS: 187 error paths exercised`, including all six serialized-lock
  controls, followed by the repository action-pin check reporting 15 immutable
  action references and by G12 confinement;
- successful 1876-job `Clean` and 1811-job `CleanTests` builds; the only
  warnings are the ten inherited `Clean.Utils.Test.TestCircuitProofStart`
  `sorry` declarations;
- 17 corpus modules, 67 vectors, two renderer fixtures, G9 on 11 source-backed
  entries with six registry entries explicitly N/A, and three optimizer
  discriminator probes;
- 17 corpus G3, 17 corpus G4, 17 corpus G10, two fixture G3/G4 and two fixture
  G10 calls; 67 interpreter and 67 execution-engine headings, each exercising
  full-witness and public scopes; 17 terminal corpus `ok` lines;
- G10a 19/19 admissions and G10b 10 lowerings / 9 exact declared exclusions:
  four felt division/modulo, four bitwise/shift, and the empty module's missing
  felt type;
- one terminal `PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12`, with no
  anchored unexpected FAIL, error, fatal, panic, abort, timeout, or termination.

The raw logs differ in exactly three lines: the two expected Nix-store tool
paths and Lean's nondeterministic replay progress prefix (`1733/1784` versus
`1734/1811`). The complete normalization used for comparison was:

```bash
for matrix in accepted-matrix.txt checked-main-matrix.txt; do
  sed -E \
    -e 's#/nix/store/(xlf4j9a1r756c8m6s7b7f88s8rqq7j58|hvvbkw0afshj37zpiilw0jwxjxfad4p4)-llzk-release-3\.0\.0#/nix/store/TOOLCHAIN-llzk-release-3.0.0#g' \
    -e 's/⚠ \[[0-9]+\/[0-9]+\] Replayed/⚠ [REPLAY] Replayed/' \
    "${matrix}" | sha256sum
done
```

Both normalized streams hash to
`0b35766895df76404d38d25c6621887ab4e452a8cbe8268b2db9829e5393b837`.

## Exact G4/G10a false-greens

The original raw `/tmp` capture was 168 lines and 12772 bytes, with SHA-256
`b046cca94ede428836600bd4cd2e440199fc7a975948efe16f4800cec36b7ddf`.
For repository whitespace checks,
[`g4-g10a-false-green.txt`](g4-g10a-false-green.txt) removes only trailing
blank characters from lines 26, 47, 50, 59, 62, and 104. The tracked copy is
168 lines and 12766 bytes, with SHA-256
`e84d999199a1576bd6497ce5dd607c594a66f8fb1e53bc4a976e4c2993e2bf58`;
its command, output, and status content is otherwise unchanged.
It uses accepted LLZK 3.0.0, vulnerable helper commit `4248ddfc`, and candidate
helper hash `48c2c39ca5a50c2b49e8defc9c8415ccd809e9bca63f85dd34ef0aa82d3274c5`.
The exact wrapper and input contents are preserved in [`flag-repro/`](flag-repro/).
That directory also preserves byte-identical positive artifact
`Multiply.llzk.txt`, SHA-256
`b7f822011ea4f1ddc9ceaecf64c8905be2c9f1da3fd75e1a1bb834f8d150a5d4`;
it is the candidate-emitted `.lake/llzk/Multiply.llzk` used by every helper
invocation in the transcript.

The transcript establishes all of these status partitions:

- real G4 rejects invalid LLZK (1), while a flag-selective success wrapper
  accepts it (0); the vulnerable helper is green (0), and the current helper is
  red (1);
- real plain verification accepts the SMT keyword canary (0), real round-trip
  rejects it (1), and a wrapper which only strips `--verify-roundtrip` falsely
  accepts it (0); the vulnerable helper is green (0), and the current helper is
  red on the canary (1);
- full inlining alone accepts a valid non-`Main` root (0), while the real product
  pipeline rejects it (1); a product-success wrapper accepts it (0), the
  vulnerable helper is green (0), and the current helper is red because no
  product IR materializes (1);
- a stronger product wrapper writes all three required positive markers and
  accepts the wrong root (0); the vulnerable helper remains green (0), while
  the current helper reaches the independent root control and is red (1).

The full matrices then run these repairs through G11 and run the exact G4 and
G10a families on all 19 artifact/fixture paths.

## Theorem and output probe

```bash
lake build --wfail Clean.Backend.LLZK.Test.Soundness
# exit 0: Build completed successfully (1776 jobs).

lake env lean doc/llzk/evidence/R8-2026-08-23/module-output-probe.lean
# exit 0
```

The focused build output is tracked in
[`soundness-build.txt`](soundness-build.txt), SHA-256
`3eb827f9a16b758f1a34b86490aafb906d08d16e2de8fff7503974bee4553ef6`.
The probe's 47-line output is byte-identical to lines 2–48 of
[`axioms.txt`](axioms.txt), whose full command/output/status record has SHA-256
`b1313ef924d3570f73f49fc523b45574ea69eb4d6e29ed6ae942abc1aca5f2e9`.
`moduleOutput_eq_of_compile` depends only on
`propext`, `Classical.choice`, and `Quot.sound`; no printed declaration contains
`sorryAx`. The old `evidence/S29/blake3g-probe.lean` remains immutable evidence
for exact historical commit `a3299ca0`; its old theorem conclusion is not
claimed to elaborate on the current API. The R8 probe is the current Phase-C
replacement and covers four explicit primary applications plus all eight
primary/source-row wrappers.

## Plonky3 non-vacuity repair

Candidate `193ec342` repaired a live README target/name and the matching required
CI job. [`plonky3-command.sh.txt`](plonky3-command.sh.txt) records the exact Bash
block run from `backends/plonky3`; it first asserts exact registered inventories
and names, then runs the complete target with `--include-ignored`. The capture
command was:

```bash
set -o pipefail
(
  cd backends/plonky3
  bash ../../doc/llzk/evidence/R8-2026-08-23/plonky3-command.sh.txt
) 2>&1 | tee /tmp/r8-plonky3-193ec342.log
# exit 0
```

The actual inline execution used the same block. Its original raw `/tmp`
capture was 43 lines and 2127 bytes, with SHA-256
`eccd895eeab5acbe7cc81005e3e2c609ba8090ac2b22e6a172ceadd7dbf4beed`.
The tracked [`plonky3-ci.txt`](plonky3-ci.txt) removes only the final empty
line and is 42 lines and 2126 bytes, with SHA-256
`2a8f96a72d14cd93d49db08fde03698424e7c6474bc6da789b3daadcaae76732`.
One Fibonacci test, two debug negative tests, two release negative tests, and
two FemtoCairo tests all passed, with zero failed, ignored, or filtered tests.
The count/name/list guards reject empty, renamed, duplicate/extra, failed-list,
failed-run, wrong-target, substring-only, and ignored-test false-greens.

[`plonky3-toolchain.txt`](plonky3-toolchain.txt), SHA-256
`d6b3e0acf88f91be86bd24df9b37985fd7d6bf74188f3c02be34792bfea89ff9`,
records the exact local replay host: Rust 1.96.0
`ac68faa20c58cbccd01ee7208bf3b6e93a7d7f96`, Cargo 1.96.0
`30a34c6821b57de0aaec83a901aca39f88f6778c`, and exact candidate hashes for
the Cargo manifest/lock, workflow, and README. The workflow itself pins Rust
1.98.0. That organization-runner input remains to be exercised by authorized
organization CI; the local replay is not described as that remote run.

## Independent frozen-tree review

The three lanes worked read-only from fresh detached clean worktree
`/tmp/clean-llzk-r8-193ec342-lanef` at exact candidate `193ec342`. Their blind
records were made on the preceding frozen-candidate pass before
`review/CONTROL-SET.md` was opened. The exact-`193ec342` restart necessarily
carried that knowledge; reviewers re-audited the complete candidate and its
two-file delta, then rechecked S1–S6 explicitly. Final lane dispositions are
recorded in [`FORMAL-REVIEW.md`](FORMAL-REVIEW.md).
The generic caller-selected table-identity boundary and D017's absent formal
LLZK semantics remain open; a green matrix does not execute `@constrain` or run
a solver.
