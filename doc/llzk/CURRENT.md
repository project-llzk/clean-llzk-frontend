# Clean → LLZK current state

Updated: 2026-08-23

Active milestone: **public-ready Clean to LLZK release candidate** — make the
repository suitable for an organization-owned home under `project-llzk`, with a
clear public reading path, current upstream base, impactful library examples,
and a frozen adversarially reviewed assurance story. Acceptance criteria and the
critical path are in `PUBLIC-READINESS.md`. Stage 1 remains finished, reviewed
three times, and reproduced by R7; all gates were green against the pinned tools
and in CI, and the pipeline milestone (a Clean circuit compiled, validated, and
its emitted constraints proved to imply the gadget's `Spec`) stands.

Latest complete frontend audit: **2026-08-22**. The review found a real A5
false-green: constraint arithmetic and member visibility were outside the
rendered-text readback, and full-witness JSON could not detect the visibility
change. The repair protects all globals, members, constraint parameters, and
`@constrain` statements; both witness backends now also check public-output JSON
on every vector; both typed readers require the exact member layout. Unused and
misleading `lower_spec` proof vocabulary and obsolete wrappers were removed.
The post-repair G0-G12 matrix passed on the accepted LLZK pin and on LLZK main
`b5c110d1`: 15 modules, 51 vectors, two scopes in both backends, 17/17 product
admissions, and 10 SMT lowerings / 7 declared skips. The reviewed repair is
frozen through clean audit commit `7c567f54`. See
`review/FRONTEND-AUDIT-2026-08-22.md` and
`evidence/AUDIT-2026-08-22/`. S29 has since completed the XOR range contract and
Xor32/BLAKE3.G promotions. The first frozen R8 candidate `c60d8363` was reviewed
and rejected on 2026-08-23 after the review found a module-output theorem gap
and claim/reproduction defects. Repair and a full R8 restart are in progress;
no candidate has passed R8 and publication remains out of scope.

Latest completed capability session: **S29 — source-visible XOR byte range and
headline promotion**. Its first
commit is decision and process only: D035 selects executable `% 256` narrowing,
exact modulo bounds, and power-of-two XOR/OR envelopes without importing hidden
circuit assumptions. Clean-only overlay `3d086f32`, built from exact upstream
base `0e53b9f2`, passed targeted and full builds plus three independent reviews
and is now the accepted source-semantics pin. Atomic adoption merge `0e9f5d03`
plus adversarial control repair `ab0affd3` passed G0-G12 on the accepted tools:
15 modules, 51 vectors, both backends and both output scopes, 17/17 admissions,
10 SMT lowerings / 7 declared skips, and 61 G11 paths. Frontend commit
`7a0f209c` now proves the recursively checked literal-modulo bound and common
XOR/OR power-of-two envelope, retains the field-prime and u64 guards, and passes
the same complete matrix. Cross-cutting Phase-X gate commit `8f0fab79` then
expanded G11 to 88 harness control cases, pins exact corpus and SMT counts, and
probes first/middle/last witness cells and output members in full-witness scope
plus public outputs in public scope; its complete accepted-tool matrix passed,
with `Bits8` derived as the widest interface at that boundary. Fixed-reference carrier
commit `046ec949` and proof/shape commit `8045dbb7` now give Xor32 its checked
reference infrastructure, exact source/module/readback shapes, certified
lookup resolution, red mutations, and concrete spec-of-compile theorem. Xor32
external-promotion commit `06b80f2f` adds the fixed seven-spec/three-compute
vector set, independent oracle, exhaustive output and old-raw discriminators,
and a clean accepted-tool G0-G12 run: 16 modules, 61 vectors, both scopes in
both backends, 18/18 admissions, 10/8 SMT, and 143 G11 control cases. Phase H
then froze its BLAKE3.G reference contract on HR `ec1b7e18`, proof and exact
shape on HP `f3951231`, and external promotion on HC `a3299ca0`. Exact
`G 0 1 2 3` carries six normalized `.spec` rows, each row's 64 fixed
official-reference-derived outputs, 96 Clean-derived internal cells, and an
exact 72-input/96-witness/64-output discriminator. Both the accepted LLZK pin
and checked LLZK main passed G0–G12 on clean HC: 17 modules, 67 vectors, G9 on
all 11 source-backed corpus modules (the other six of 17 are registry modules
and G9 is N/A), 19/19 admissions, measured SMT 10/9, and 177 G11 control cases.
Independent adversarial review is required at every phase boundary. See
`sessions/S29-xor-range-contract.md`, `evidence/S29/bounds.md`,
`evidence/S29/bounds-gates.txt`, `evidence/S29/harness-gates.txt`, and
`evidence/S29/xor32-proof-gates.txt`, `evidence/S29/xor32.md`,
`evidence/S29/xor32-gates.txt`, `evidence/S29/blake3g.md`, and
`evidence/S29/blake3g-gates.txt`.

Latest completed frontend-alignment session: **S25** — upstream Clean was fetched and accepted at
`0e53b9f2d05f06defa2aa0a859f549b611583f10`, moving the host to Lean 4.32.2.
Compatibility commit `6ccca6f8` preserves the accepted frontend subset, makes
all new witness-IR constructors fail closed with named diagnostics, and records
the real `U64Expr.val` truncation boundary as D026. G0-G12 passed; evidence
is in `evidence/S25/`. No branch was pushed and the integration branch remains
untouched.

Latest completed assurance session: **A7** — copy canonicalisation is now an
explicit `CopyCanon.run` used by `WitnessSet.ofSource`.
`CopyCanon.step_preserves` proves the single-cell update and `run_preserves`
proves the whole-list invariant: the representative map preserves the value of
every circuit variable. The existing copy-chain and non-copy red controls remain
green; theorem evidence is in `evidence/A7/`. This feature branch has not been
pushed; commit `a32593bf` was subsequently integrated into the audited baseline
and is ancestral to the current branch and live replacement repair. Full G0-G12
passed on that clean commit: 12 modules, 33 vectors through both witness
backends, 2 renderer fixtures, G10a 14/14, and G10b 10 lowered / 4 declared out
of scope.

Latest completed presentation increment: **checked public showcase** —
`EXAMPLES.md` is generated from `Corpus.corpus`; unknown or failed entries,
empty vector sets, and invalid agreement states refuse generation. G1 compares
the generated and checked-in page byte-for-byte, while `Test/Showcase.lean` pins
the corpus ordering, denominator, vector total, source-backed count, and purpose
coverage. Full G0-G12 passed on clean commit `b16bb83e`; evidence is in
`evidence/P0/showcase.txt`.

Latest completed repository-hygiene increment: `SECURITY.md` defines the future
private-reporting path without pretending it is already enabled; the PR template
requests pins, gates, trust-boundary changes, and public impact; and
`PUBLICATION.md` prepares the organization metadata, four required checks,
branch protection, security settings, and anonymous verification procedure.
Active docs no longer depend on a developer-local path. Read-only GitHub checks
confirmed the relevant security features are not inherited from `llzk-lib`.
Evidence is in `evidence/P0/publication-hygiene.txt`; no external state changed.

Latest completed CI-hardening increment: every external action is a reviewed
commit SHA; hosted jobs name Ubuntu 24.04; Plonky3 names Rust 1.98.0; and the
main token defaults to contents read-only. The LLZK job uses the accepted public
substituter/key with source builds disabled. All hosted and self-hosted benchmark
entry points are inert unless `CLEAN_BENCH_ENABLED == 'true'`, which publication
keeps unset pending a runner threat review. At that commit G11 exercised 53
error paths, including ten controls for these policies; the later frontend
audit added the public-scope discriminator as path 54. Full G0-G12 passed on
clean commit `9b809e32`; evidence is in `evidence/P0/ci-hardening.txt`. The
workflows have not run remotely at this commit, and no external state changed.

Latest completed dependency session: **L0** — both the previous LLZK input
`5db6f8f9` and candidate `25fb3740` were materialized by exact Nix flake
reference and run against the same frozen post-S25 frontend tree. Both passed
G0-G12 with identical counts and declared diagnostics. D032 advances the
accepted LLZK pin to `25fb3740`; the comparison and theorem audit are in
`evidence/L0/`. The required post-pin run passed on clean commit `5fe8f465`.

Latest completed capability session: **S26** — bootstrapped 2026-08-21 from
final L0 evidence tip `884d5b1c`. D033 makes the width/field and
`U64Expr.val` bridge executable:
every admitted u64 value is proved below the field prime, narrow-field `.val`
is exact, and wide-field `.val` is refused. Structural lowering and the
independent G9 reader cover bounded add/mul/div/mod, bitwise operations, literal
shifts, and `VExpr.bitsOf`; `eval_lt_upperBound` and `eval_ofWitgen` discharge
the source semantics. The conformance corpus has grown to 14 artifacts and 45
vectors with lookup-free `LowByte` and `Bits8` entries. The re-measured gadget
sweep removes `And8`'s `land` diagnostic but retains XOR diagnostics whose byte
bounds exist only outside witness IR. G0-G12 passed on clean implementation
commit `8951f016`; evidence is in `evidence/S26/`.

Latest completed capability session: **S28** — bootstrapped 2026-08-21 from final S26 evidence tip
`91d43ffd0b4dcfd0841cc97f402b2d6006c58358`. Its scope is to retire D013 with
row-preserving multi-column tables and certificates, then demonstrate `And8`
end to end. The mandatory pinned-LLZK syntax probe and row/certificate decision
preceded lowering. A pre-implementation adversarial review strengthened the
packet's G9 and certificate-carrier obligations and added the missing exact
wide-field `.val` refusal fixture; its targeted warning-free build passed, with
evidence in `evidence/S28/pre-implementation-review.txt`. D034 is now
implemented: the IR, renderer, recognizer, G9 readers, and certificate chain all
preserve ordered rows; the full `ByteXorTable` is certified; and `And8` is the
fifteenth corpus artifact with six vectors. G0-G12 passed on clean
implementation commit `03bf2f9b`; scale and theorem evidence are in
`evidence/S28/`. The requested post-completion adversarial review found and
repaired an unchecked `lowerRecognized` retained-table registry and the missing
module-lookup-to-source-row soundness bridge. The clean repair commit
`129fbe6e` passed G0-G12; no confirmed review finding remains open. No push or
external issue creation has occurred.

Integration branch: `clean-to-llzk/integration`

Active working branch: `clean-to-llzk/s29-xor-range-contract` (Phase H
implementation sealed on `a3299ca0`; S29 documentation closure is `c60d8363`;
that first frozen R8 candidate was rejected and its repair is in progress)

Integration commit: `9b46264c59ed69af24817cb4b2cfdb7ebcfb4629`

Pinned upstream Clean base: `0e53b9f2d05f06defa2aa0a859f549b611583f10`

Accepted Clean overlay: `3d086f32a71d17cbddfb46c0dea63cd36c8aa552`

Local integration state, reconciled 2026-08-22: `clean-to-llzk/integration` was
fast-forwarded from stale R7 tip `97390fac` to audited baseline `9b46264c`; the
feature branch starts at that exact commit. The local integration ref is 109
commits ahead of the locally recorded fork ref. External publication state was
last verified 2026-08-21: fork PR #1 was at `7ff51310`, with all four CI jobs
green there. A public release candidate must put the branch, evidence, and CI
on the same frozen commit. No push or other external change occurred during
this reconciliation.

Dependency state, updated 2026-08-22: Clean upstream provenance remains exactly
`0e53b9f2`. S29 adopts reviewed direct-child overlay `3d086f32`, whose only
change is executable Xor32 byte narrowing; it is not claimed upstream. LLZK
`main` at `25fb3740` remains the accepted
source/tool pin after L0's same-tree comparison with the previous `5db6f8f9`
input. Both exact outputs report 3.0.0 and passed 12 circuits, 33 vectors on both
witness backends, 2 renderer fixtures, all 14 product-program admissions, and
the unchanged 10-lowered/4-declared-out-of-scope SMT split. The candidate was
substituted from the public cache with source builds disabled.

The accepted 25-commit delta touches LLZK core transforms, analysis, memory,
SMT, and `llzk-witgen`, not only unrelated backends. D032 records why its
relevant correctness fixes justify advancing despite the absence of a newer tag
and the large transform surface. The immutable SHA and L0 evidence are the
authority; the unchanged 3.0.0 version banner is not.

## Accepted pins

- Upstream Clean: `0e53b9f2d05f06defa2aa0a859f549b611583f10`
- Accepted Clean overlay: `3d086f32a71d17cbddfb46c0dea63cd36c8aa552`
- LLZK source: `25fb3740ea3465c9129a06289297bb4f0554b7a5`
- LLZK tools: the Nix output of the pinned LLZK source; reports version 3.0.0
- project-llzk VeIR: `eae1c27e7842c0503233ec99155c39791bd5f502`
- upstream VeIR: `a4e6194d5810a02d74f0094ff6014cda6db6d617`

See `PINS.md` for how to obtain the tools, including the cache-key requirement.

**The upstream Clean pin is current as fetched on 2026-08-21; the accepted
source-semantics pin is S29 overlay `3d086f32`.** S25 merged the 70-commit delta
at `0e53b9f2` and moved Lean from 4.30.0 to **4.32.2**. S29 changes only Xor32's
witness byte narrowing on top. The backend now
matches `U64Expr`, `ofU64`, `letU`, `BExpr.flt`/`bit`, and
`VExpr.envRange`/`bitsOf` exhaustively while preserving the old accepted subset.
The non-obvious cost found by S25 was D026: `U64Expr.val` truncates. S26's D033
now turns that temporary theorem premise into a structural policy: narrow-field
`.val` trees are eligible only while every nested value remains below the prime,
and bn254/grumpkin `.val` trees are explicitly refused.

## Reproduce everything

From a fresh checkout, in this order — every line of it is load-bearing, and S24
established that by running it (`evidence/S24/clean-checkout.md`):

```bash
# 0. If the tree carries someone else's lock and you know that session is done:
#    `reclaim` alone only works for a numeric owner this machine can prove dead.
#    An LLZK_SESSION owner is opaque, so you have to name it (D024).
#      bash scripts/llzk/worktree-lock.sh status
#      bash scripts/llzk/worktree-lock.sh reclaim "what you are doing" --from '<id>'

# 1. G0 checks provenance against `upstream`, which a fresh clone does not have.
git remote add upstream git@github.com:Verified-zkEVM/clean.git

# 2. Fetch mathlib's build cache. Skipping this does not fail — it builds mathlib
#    from source, 1837 targets, and that dominates everything else here.
lake exe cache get

# 3. Build/substitute the pinned LLZK tools. The command prints a machine-local
#    Nix store path; PINS.md records the required cache key.
nix build --no-link --max-jobs 0 --print-out-paths \
  github:project-llzk/llzk-lib/25fb3740ea3465c9129a06289297bb4f0554b7a5#llzk
export LLZK_OPT=/the/printed/store/path/bin/llzk-opt
export LLZK_WITGEN=/the/printed/store/path/bin/llzk-witgen

# 4. The gates.
(
  set -e
  export LLZK_SESSION="manual-reproduction-${BASHPID}"
  bash scripts/llzk/worktree-lock.sh claim "what you are doing"
  trap 'bash scripts/llzk/worktree-lock.sh release' EXIT
  bash scripts/llzk/e2e.sh
  bash scripts/llzk/worktree-lock.sh release
  trap - EXIT
)
```

`e2e.sh` refuses to run without the worktree lock (S24): it rebuilds
`.lake/llzk` from scratch, and evidence is only attributable to a commit if one
session owned the tree while it ran. The subshell above releases the lock on
success and, through its `EXIT` trap, on failure. **From an agent harness, set
the same `LLZK_SESSION=<label>` on every separately launched lock/gate command**
— each command there is its own POSIX session, so the default identity does not
survive from the claim to the run.
`doc/llzk/CONCURRENCY.md` has the why.

Expected: `PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12` — 17 corpus
modules, 67 input vectors, both witgen backends, and 2 renderer fixtures. G10a must admit all
19 modules; the measured G10b split is exactly 10 lowered / 9 declared skips and
is pinned by the gate rather than inferred from the corpus count.

CI is *configured* to run G0, G11 and G12 on every pull request, and G1–G10 in
the `llzk-e2e` job, which builds the pinned LLZK from the same flake reference
`PINS.md` records. Until R5 none of the LLZK gates were in CI at all.

**It has run, and it was green.** This paragraph said "None of it has ever run"
from `262c9684` until 2026-08-04, and it was false for two of those days.

The facts, from `gh run list --branch clean-to-llzk/integration`:

- `alexanderlhicks/clean` **PR #1** was opened 2026-08-02T03:18:55Z — three
  minutes after S24 took the worktree lock.
- CI ran on it at `4e15d3ad` three seconds later and **all four jobs passed**:
  `build`, `llzk-harness`, `llzk-e2e` and `plonky3-backend`.
- So `llzk-e2e` works on a GitHub runner, including
  `nix build …#llzk` — the risk this document and R6 both flagged as the likely
  first failure did not materialise.

**How this survived.** S24's handoff recorded "S24 asked and got no answer, so
nothing was pushed and the jobs stay marked unrun". The push and the PR happened
anyway, minutes later, and no session updated the paragraph. R6 then *read* it,
repeated it in its roadmap as "CI has never run / untested code", and did not
check — while auditing this project for exactly that. A1 and A2 carried it
forward again. One `gh run list` would have falsified it at any point.

It is the same lesson as R6-2 and R6-3, in the place hardest to see: **a claim
about the world outside the repository has to be checked against the world, and
the control plane is not evidence about itself.**

**What it cost, which nobody had measured either.** `llzk-e2e` took **4h23m** on
2026-08-02 (03:22:08 → 07:45:45) and the 2026-08-04 run is on the same step at
the same pace. Essentially all of it is step 6, `nix build …#llzk`, building LLZK
from source because the runner has no substituter for it; `llzk-harness` by
contrast is 11 seconds.

That matters for two reasons. GitHub's per-job limit is 6 hours, so the job
currently finishes with about 25% of head-room and a slower runner or a heavier
LLZK would turn a green gate into a timeout — a failure mode indistinguishable
from a real one. And every push to the PR spends four and a half hours of runner
time, which makes `llzk-e2e` something to trigger deliberately rather than a
check you get on each commit.

The CI-hardening branch now installs the exact public substituter and key from
`PINS.md` and passes `--max-jobs 0`. L0 established that the newly accepted
output is in that cache, so CI now downloads it or fails instead of silently
building LLVM from source. This configuration has not yet run remotely at its
own commit, so the expected duration reduction is not evidence; organization CI
on the frozen candidate must establish anonymous cache access and the actual
runtime.

What is still true: every gate in the table below is green on one machine *and*
on a runner, but only G0–G12 are gated in CI; §11 still reserves publishing for
an explicit decision, which was given.

## State

- Completed:
  - S00 control plane; S03 emitter IR and renderer; S04 analysis, layout and the
    assertion-only slice; S05 the natural division/modulo shapes; S06 tables and
    lookups; S07 the emitter command and harness; S01 tooling; S02 validation.
  - **R2**, the Stage-1 adversarial acceptance review: returned for repair, 15
    findings. `review/R2-findings.md`.
  - **S08–S15**, the repair: every finding discharged, with the resolution and
    its evidence in `review/R2-resolution.md`.
  - **R3**, a review of that repair: three defects in its own new code, fixed.
    `review/R3-findings.md`.
  - **S16–S18**, closing the three gaps the repair had documented rather than
    fixed: D012's lookup rows (proved), G9's scope (now every `Source`
    successfully returned by the supported checked path, not merely the corpus),
    and R2-05's field law (now a required class).
  - **S19**, the witness side of G9, and the corpus outside
    `Addition8FullCarry`'s `Assumptions`.
  - **R4**, two *independent* adversarial reviews — the first review of this work
    by anything other than the session that wrote it. Nine findings, five
    breaking a written claim, two of them severe. All fixed and every
    counterexample re-run. `review/R4-findings.md`.
  - **R5**, five independent adversarial reviews run against a frozen tree —
    theorem statements, documentation versus elaborated reality, a red team,
    gate falsification, and the trusted base. One soundness break (a `Config`
    could weaken the emitted constraint system with every gate green), one
    completeness break (a proved `FormalCircuit` refused and told to file a
    backend bug), and nine claims stated more strongly than the code supported.
    `review/R5-findings.md`; the boundaries it established are `GAPS.md`.
  - **S21–S22**, the repair: the doors confined (G12), the harness's own error
    paths gated (G11), D011's side conditions moved below every door, and the
    LLZK gates put into CI for the first time.
  - **S24**, finishing Stage 1. The worktree lock became a gate — and wiring it
    in exposed that it did not protect agent sessions at all, because the POSIX
    session id it defaulted to is the *command* under a harness, so a claim was
    stale by the next command and `claim` took a stale lock silently. `reclaim`
    is now separate, `LLZK_SESSION` is the identity, and CI claims rather than
    being exempted (D023). Then S23 was executed: `CertifiedConfig F` carries
    the table certificates to the five supported checked entry points in
    `WitnessCheck.lean` (R7-15 corrected "seven", which had counted two
    theorems), which no longer accept a plain `Config`, so `GAPS.md` §1's first
    half — the *erasure* — is closed. Its
    second half is not, and is upstream.
  - **R6**, an adversarial review of the finished Stage 1 and its repair. The
    gates reproduced on the reviewed commit before anything changed; four claims
    were attacked specifically and held, above all D019's survival through
    elaboration. Six findings, all fixed: `reclaim` was unreachable for every
    identity D023 introduced it for (D024); `GAPS.md` item 2's counterexample was
    one the toolchain *does* catch, and the correct one is now recorded and
    verified; Clean-core byte-identity was an invariant three documents argue
    from and no gate checked; `copyCell` — the one shape this project has
    demonstrably misread — was in neither the goldens nor the corpus and had
    reached no LLZK tool; `ROADMAP.md` overstated four closed gaps; two stale
    pointers. `review/R6-findings.md`.
  - **A1**, closing `GAPS.md` §4 — the first item of the roadmap below.
    `Lookups.lean` gives the lookup half of `ConstraintsHoldFlat` the semantic
    theorem the assertion half had had since S15, and `Test/Lookups.lean`
    instantiates it, and `byteTable_lookup_iff`, at `Addition8FullCarry`. What
    made it possible was making "the compiler ran a check" into a proposition:
    `registryOk_of_recognize` and `size_eq_of_recognize` (D010 as a theorem) turn
    a successful `recognize` into the canonicity bound `certified_membership`
    needs, so nothing is assumed at the call site. Two behaviour-preserving
    refactors of `recognize` were needed first — an overlapping `match` that
    generated no equation lemmas, and a `for` loop that hid the field check
    inside `forIn`. No new axioms.
  - **A2**, closing `GAPS.md` §3 — the statement R5e said a user most likely
    assumes the project has. `Soundness.spec_of_compile` is a conditional
    soundness implication: for an assignment satisfying every reader-extracted
    equality and ordered lookup row, under exact input evaluation and the gadget
    assumptions, the gadget `Spec` holds for the typed output reconstructed from
    the module's ordered `@out{j}` assignment. R8 found and repaired an earlier
    version that concluded only for Clean's internally recomputed output.
    Concrete resolution/no-interaction
    obligations are proved for `Addition8FullCarry`, `And8`, Xor32, and exact
    BLAKE3.G `G 0 1 2 3`; compilation, readback, recognition, equality/lookup
    satisfaction, input evaluation, and assumptions remain explicit premises.
    G12 also became a code-reading check rather than a grep over comments, after
    three files in one session had been added to its allowlist for prose alone —
    the allowlist shrank instead.
  - **A4**, closing `GAPS.md` §6. Both G9 readers now take the expected `Ty` and
    check it at every operand, parameter, `struct.member` and `global.def`;
    array types are checked exactly against the global being read, length
    included. `Test/Constraints.lean` pins R5e's own counterexample — reading a
    babybear module as `bn254` — going red on both readers. Turning the check on
    immediately found a defect in the tests it was meant to protect: a `#guard`
    compared every corpus module against a hard-coded babybear, wrong for five of
    the six `Square_*` entries, so `Corpus.Entry` now carries its `FieldSpec`.
  - **B**, publishing — and the finding that it had already happened. See
    "Reproduce everything" above: PR #1 has been open since 2026-08-02 with CI
    green on all four jobs, while this document said none of it had ever run and
    R6 repeated that in its roadmap without checking.
  - **R7**, five independent adversarial reviews of the finished Stage 1, the
    closed gaps, the gates, and — for the first time — the *plan*. What held:
    the gates (reproduced before anything changed), the soundness chain link by
    link, axiom hygiene exactly as documented, the fatBytes attack blocked by
    `resolve`, and the R2-06/R4b-2 vacuity class still closed. What did not:
    the coverage headline — "bitwise blocked by exactly two constructors" was
    false, 80–89% of its own diagnostics being multi-column-lookup refusals
    (R7-05), so **D013's retirement is now on the critical path (S28)**; S25's
    "translate exactly, re-prove `eval_ofWitgen`" is unsatisfiable because
    upstream `U64Expr.val` truncates (R7-08); S27's premises were false three
    ways — GF(2) not bn254, no bitwise ops, real blocker `letF` (R7-09); G0
    never looked at the working tree it certified (R7-01, fixed + G11 case);
    three refusal paths had no fixture (fixed, 29 before S25, 34 after it, and
    35 after the pre-S28 wide-field `.val` control);
    `CertifiedTable` had no
    name tie, leaving `spec_of_compile`'s lookup hypothesis incomparable with
    module satisfaction under swapped names (R7-12, now a name conjunct of
    `ExportTable.Certifies`); the coverage sweep was unreproducible (fixed —
    `Test/Coverage.lean` pins every verdict and its decomposition); and eight
    document-drift items (R7-13…17). `review/R7-findings.md`,
    `evidence/R7/`.
  - `Gadgets.Addition8FullCarry` compiles to LLZK, `llzk-opt` accepts,
    round-trips and product-forms it, both witgen backends reproduce Clean's
    witness on every recorded input, and its emitted `@constrain` is Clean's own
    constraint system.
  - **A5**, closing `GAPS.md` section 2. `Module.render` reads the three
    constraint-only statement forms back from text, including independently
    reconstructed types and the function boundary, before releasing an
    artifact. `Module.render_constraintSurface` states the generic round trip;
    five mutations make it red. G0-G12 passed on clean commit `28132f64`.
- Completed locally: **S26**, bootstrapped from L0 evidence tip `884d5b1c`;
  D033, the structural lowering, theorem-backed independent reader, corpus, and
  measured coverage update are implemented and G0-G12 are green on `8951f016`.
- Decision complete: D033 settles the width/field policy and `U64Expr.val`
  bridge as a recursively proved bound plus explicit refusal.
- Completed locally: **S28**, from final S26 evidence tip `91d43ffd`. D034,
  row-preserving multi-column lowering/readback, the full 65536×3 certificate,
  and the six-vector `And8` corpus entry are green on `03bf2f9b`.
- Completed locally: **S28 post-completion adversarial review**. It found two
  confirmed issues, repaired both, and reran G0-G12 on clean commit `129fbe6e`.
  No confirmed review finding remains open; residual project-wide boundaries
  remain named in `GAPS.md`.
- Completed locally: **S29 Xor32 proof and exact-shape boundary**. The source,
  recognized form, typed module, independent witness and constraint readers,
  four certified ByteXor lookups, red mutations, and concrete
  `xor32_spec_of_compile` instantiation are pinned on clean commit `8045dbb7`.
  G0-G12 passed with the deliberately unchanged 15-module/51-vector corpus;
  this remains the proof boundary beneath the later promotion.
- Completed locally: **S29 Xor32 external promotion**. Clean implementation commit `06b80f2f`
  adds seven normalized and three compute-only fixed-reference vectors, an
  independent oracle, exhaustive four-output attacks on the wide rows, the
  exact old-raw row-9 discriminator, and whole-driver reachability controls.
  G0-G12 passed with 16 modules, 61 vectors, 18 admissions, 10/8 SMT, both
  scopes/backends, and 143 G11 control cases.
- Completed locally: **S29 BLAKE3.G Phase H**. HR `ec1b7e18` freezes the
  reference contract, HP `f3951231` the proof/shape boundary, and HC
  `a3299ca0` the exact `G 0 1 2 3` external promotion. Both full toolchain
  matrices passed with 17 modules, 67 vectors, 19 admissions, 10/9 SMT, both
  scopes/backends, and 177 G11 control cases. Documentary closure HD
  `c60d8363` became the first frozen R8 candidate; R8 rejected it. The replacement
  repair has not passed the two-toolchain matrices or restarted R8.
- Blocked: none.

## Last green gates

Evidence under `doc/llzk/evidence/`.

Latest complete two-toolchain run: clean S29 BLAKE3.G implementation commit
`a3299ca06576b81586ddbe56a9de711e12f1a8cd`; see
`evidence/S29/blake3g.md` and `evidence/S29/blake3g-gates.txt`. All G0–G12
passed against accepted LLZK `25fb3740` and checked LLZK main `b5c110d1`: 17
modules, 67 vectors, G9 on all 11 source-backed corpus modules (the other six of
17 are registry modules and G9 is N/A), 19 admissions, measured aggregate SMT
10/9, and 177 G11 control cases.
BLAKE3G is the widest interface. Its committed probe has no `sorryAx` and names
all seven axioms in its inherited closure; the theorem remains conditional and
D017 remains open.

| Gate | Result |
|---|---|
| G0 state and pins | PASS — and since R6 it also fails on any change to Clean's core outside `Clean/Backend/LLZK/`, `Clean.lean` and `Clean/Test.lean` |
| G1 lint + `lake build --wfail Clean` + `lake build CleanTests` | PASS |
| G2 renderer: goldens plus checked semantic-surface round trip | PASS — 2 renderer fixtures, 17 corpus modules, including arithmetic, visibility, parameter, member, and nested-table red mutations |
| G3 `llzk-opt` parse and verify | PASS — 17 modules + 2 fixtures |
| G4 `llzk-opt --verify-roundtrip` | PASS — 17 modules + 2 fixtures |
| G5 `llzk-witgen` interpreter | PASS — 67 vectors in full-witness and public scopes |
| G6 `llzk-witgen` execution engine | PASS — 67 vectors in full-witness and public scopes |
| G7 both backends vs checked expectations | PASS — `--check-output` uses Clean-derived cells plus fixed Xor32/BLAKE3.G outputs checked equal to Clean before expected-JSON emission |
| G8 fail closed | PASS — exact negative fixtures include the new bound, shift-count, dynamic-operand, index, and oversized-`bitsOf` refusals, plus tool-version rejection |
| G9 the emitted `@constrain` **and** `@compute` are the circuit's | PASS — both preconditions of emission for all 11 source-backed corpus modules; the other six of 17 are registry modules and G9 is N/A (D018, D020) |
| G10a LLZK analysis pipeline admits the module | PASS — all 19 |
| G11 the harness's own control cases | PASS — 177, including positive baselines, lock/core/policy controls, Xor32 raw/output attacks, whole-e2e reachability mutations, and BLAKE3.G exact-layout/content-aware controls |
| G12 reads code, not comments | PASS — A2; a docstring naming an entry point is no longer a call site, so the allowlist shrank rather than grew |
| G9 compares types | PASS — A4; both readers check every `Ty` against the configured field, and array types exactly against the global read. Was `GAPS.md` §6 |
| G12 every gate-skipping entry point is confined | PASS |
| G10b SMT lowering | PASS — 10 lowered, 9 out of scope for a declared reason |

Every gate is checked to be falsifiable, and the checks are part of the gate
rather than notes about it:

- the witness gates, by `require_llzk_witgen_discriminates`, which requires both
  backends to accept the baseline and reject canonical first/middle/last
  mutations in the available witness-cell, full-output, and public-output
  groups; the separately derived widest interface requires all three positions
  in every group to be distinct (R2-06, S29);
- BLAKE3.G's lane-marker discriminator additionally requires the exact
  72-input/96-witness/64-output carriers, then makes both backends reject every
  one-cell `w0`–`w95` mutation in full scope and every one-member
  `out0`–`out63` mutation in both scopes; inputs are layout, canonicality, and
  association checked, not individually mutated;
- G3, G4 and G10, by `require_llzk_opt_discriminates`, which requires `llzk-opt`
  to reject a non-MLIR file *and* a well-formed MLIR module that is invalid LLZK
  — a shim answering only `--version` used to make all three vacuous while the
  harness printed PASS (R4b-2), and the non-MLIR probe alone was satisfied by any
  generic MLIR parser, which LLZK 3.0.0 itself demonstrates by accepting a module
  containing no LLZK at all (R5d);
- G9, by `Test/Constraints.lean`, which perturbs the Clean side six ways and
  pins that the comparison goes red for each;
- G10a, by the control in `evidence/S08-S15/controls.txt`: a module whose root is
  not `@Main` fails it;
- G10b, by exact acceptance and declared-refusal totals: this catches either an
  unbalanced new refusal or a permissive new acceptance; compensating
  per-artifact swaps remain visible in the named logs rather than hidden by a
  claim about the aggregate;
- and the checks themselves, by G11 — `scripts/llzk/test-scripts.sh`, which
  drives each one against a shim built to defeat it. Until R5 nothing exercised
  any harness failure branch, which is how a repair to `check-pins.sh` shipped
  dying with `llzk_fail: command not found` instead of the message it was written
  to print, and survived two reviews.

## What is still not established

**`doc/llzk/GAPS.md` is the register.** It exists because this section used to be
the register and was not one: it listed "one boundary and one improvement", and
R5's five reviewers found nine claims across the codebase that were stated more
strongly than the code supported. Two of them were consequences of paragraphs
that stood right here. The list below is the summary; `GAPS.md` is the thing to
read, and the docstrings it points at now agree with it.

The largest still open, in order (R7-14 — an earlier version of this paragraph
kept listing §3 and §6 after other sections of this same file recorded them
closed): the generic compiler API cannot tie a caller-certified `RawTable` to
an arbitrary circuit's erased `RawTable` (D012 —
and the `ConstraintSet.globals` conjunct that claimed to close this is a
tautology; S24 closed the *erasure* half, so the certificate reaches the
compiler, and R7 tied it to the table's *name*, but not to the circuit's own
table). Current lookup-bearing headlines discharge `resolve` through
circuit-specific proofs, but that does not close the generic caller-selected
identity gap. There is also no whole-translator preservation theorem. The unused
`FieldExpr.lower_spec` fragment was retired on 2026-08-22 after R5 showed that
five grossly wrong lowerings satisfied it and that it did not compose. (§4 was
on this list until A1 closed it; §3 until A2 —
`spec_of_compile`, whose lookup hypothesis now ranges over the module reader's
ordered `C.lookups` after the S28 review closed R7-12's remaining bridge;
§6 until A4; §2 until A5's checked textual constraint-surface round trip; and
§8's copy-canonicalisation premise until A7.)

The lookup side, which R4a-6 found had no semantic theorem, has one:
`Lookups.ofSource_lookups_iff`, the counterpart of `ofSource_eqs_iff`. This
paragraph used to say its canonicity hypothesis was "discharged from the
compiler's own registry check", and R5a-7 corrected that to "nothing instantiates
the theorem, so nothing discharges its hypothesis". Since A1 the original
sentence is true and is a theorem: `canonical_of_recognize` derives the bound
from `registryOk_of_recognize` and `size_eq_of_recognize`, and
`Test/Lookups.lean` instantiates it for Add8, And8, Xor32, and heterogeneous
BLAKE3.G; the exact resolution proofs tie their operations to Bytes and/or
ByteXor. Successful recognition remains a named checked premise rather than a
kernel-reduced fact.

**D017 — the reading of LLZK — cannot be closed from this repository.**
`llzk-witgen`'s help text says it outright: *"llzk-witgen v1 ignores constrain()
and traps on bool.assert."* There is no executor for `@constrain` in the pinned
toolchain, and no formal LLZK semantics in Lean, so the assumption that
`constrain.eq` is equality and `constrain.in` is membership has no independent
runtime-executor check and cannot acquire one here. Lean readback and conditional
theorem evidence do not execute constraints. Closing D017 means formalising LLZK, which is
VeIR's project (D003). The `@compute` half of the same reading *does* have
evidence: 67 vectors across both LLZK witness backends (61 with a Clean circuit
behind them). The six BLAKE rows add fixed independent public outputs, while
their 96 internal cells remain Clean-derived; S26's direct bitwise/shift probes
remain separate evidence.

**S20's partial preservation theorem was retired.** Every module the supported
checked `compile` entry point returns has been compared against its
circuit on both sides, so a lowering bug yields a *refusal*, never a wrong
module; that part holds.

Two corrections R5 forced. The refusal is no longer "merely never-observed" — R5c
observed one, on a proved `FormalCircuit` whose emitted module was correct, and
the reader was at fault. The `FieldExpr.lower_spec` theorem S20 produced turned
out to be satisfied by a lowering that throws on every expression, one that
emits everything in the wrong field, and one that appends a bogus
`constrain.eq %v, 0` to every subexpression. Lifting it through the assembly
loops — the plan for S21 — would have been lifting almost nothing; R5a-4 gives
three obstructions. Since nothing consumed it, the 2026-08-22 audit removed the
proof and its private reader vocabulary instead of presenting it as active
assurance. `GAPS.md` item 5 records what a replacement must establish.

It was attempted, and the attempt found that the obstacle is not the one D018
implied. It is not the state monad: it is that `Value.mk`, `Builder.fresh`,
`Builder.emit` and `BuilderState`'s fields are all private — D005's first
invariant, which R4b-3 had just tightened — while `FieldExpr` lives in a module
that imports them, so the proof has nowhere to live. **D021** records the three
ways out and recommends one (make the emitters pure functions and keep the monad
as a wrapper). The attempt was reverted rather than left half-built; nothing in
the *backend* carries a `sorry` — and its axiom closure is clean, checked by
`#print axioms` in `evidence/R7/probes.txt`. (Not "nothing in the tree": pinned
Clean core carries one at `Clean/Circomlib/Poseidon.lean:22`, outside the
backend's closure, plus deliberate ones in `Clean/Utils/Test/` — R7-16.)

Two smaller facts, stated so they are not mistaken for gaps: the whole-vector
witness statement rests on the block-prefix discipline `Analyze` enforces rather
than proves; and no solver has run on an emitted module, because `llzk-smt-check`
needs SMT-LIB that no pass in the pinned `llzk-opt` produces.

## Known constraints

- The frontend is a pure Lean backend in Clean which emits textual LLZK.
- VeIR is an independent consumer/proof track, not an initial dependency.
- Stage 1 accepts only the fail-closed subset in `ROADMAP.md`.
- The root component is always `@Main` (D015); the circuit's name is the
  artifact's file name.
- Heavy Nix and Lean builds must not run concurrently on this machine; doing so
  produced a spurious Lean target failure during S00, and again during S24 — that
  time with the mechanism identified. `Clean/Gadgets/ByteDecomposition/`
  `Theorems.lean:62` is a `bv_decide`, so it is subject to a **solver time
  limit**: under load it fails with "The SAT solver timed out while solving the
  problem" and G1 goes red on a tree that is correct. It succeeded on retry with
  nothing changed. `evidence/S24/clean-checkout.md` finding 4.

## Active session and handoff sequence

**Claim the worktree first** — `bash scripts/llzk/worktree-lock.sh claim "..."`,
and set `LLZK_SESSION` if you are an agent session, or the claim will not survive
your next command. `e2e.sh` refuses without it. If the tree already carries a
finished session's lock, `status` will say whether `reclaim` needs `--from`
(D024). Three sessions collided on 2026-08-01; `CONCURRENCY.md` records the cost.

## The capability sessions, as R7 corrected them

Bootstrapped 2026-08-04; **R7 falsified parts of all three packets against the
primary sources before execution** (R7-08…11), and the corrections are written
into the packets themselves. Read them in order.

| packet | does | R7 correction |
|---|---|---|
| `sessions/S25-align-upstream.md` | bump to upstream `0e53b9f2` / Lean 4.32.2 | constructor inventory fixed (three errors); **Deliverable 2a added**: upstream `U64Expr.val` truncates, so `eval_ofWitgen` cannot be re-proved as stated — restating it costs bn254/grumpkin div/mod coverage and must be recorded as a decision (D026), which no gate can see |
| `sessions/S26-witness-u64.md` | bounded structural `U64Expr` and direct `bitsOf`; `ite` remains refused | implemented locally as D033; adds lookup-free `LowByte`/`Bits8`, but correctly retains XOR whose bounds are not in witness IR |
| `sessions/S28-multicolumn-tables.md` | **new** — retire D013: `array.new`, multi-dim `constrain.in`, certification at 65536×3 | unlocks `And8`; at S28, XOR-family promotion still needed the source-visible range contract S29 Phase B now supplies |
| `sessions/S27-fork-gadgets.md` | port `~/zkgolf/submission_gf2` onto fork `main` | **returned for re-scoping** (R7-09): the submission is GF(2) — not an LLZK field — has zero bitwise ops, and its real blocker is `letF`. The port survives as Clean-side library work; its backend payoff needs a decision first |

S25 keeps the accepted subset exactly the size it was, so its gates say one
thing only: the bump did or did not break the backend — except D026, which only
the theorem statement and the decision register can express (R7-08's point: the
realistic bump failure is green gates over a silently weakened theorem). S26 is
where capability grows; S28 is where the *library* does.

## Roadmap after R7

Stage 1 is finished, reproduced, and reviewed three times by sessions that did
not write it. What remains sorts into five tracks. S28 and its post-completion
review are accepted; S29 Phase B, Xor32 Phase X, and BLAKE3.G Phase H are
complete. This documentation-only closure completes S29; next select and freeze
one candidate, then begin R8. That selection subsequently produced `c60d8363`;
R8 rejected it, and the repair/restart is now in progress.

**The two milestones, stated in the grant's terms.** Milestone 1 — one Clean
circuit compiled through the whole LLZK pipeline, validated end to end — is
**done and revalidated by R7**: gates green on this machine and in CI, the
formal chain attacked and held. Milestone 2 — the *library* of Clean circuits —
is what the corrected plan below is for, and its honest denominators are in
`ROADMAP.md`'s coverage section. The checked 12-gadget sweep now has 10
compile-capable rows: seven arithmetic rows plus Xor32, And8, and exact
BLAKE3.G. S26+S28+S29 Phase B supplied those bitwise gains; raw-XOR Keccak
remains refused. The witness-IR loop increment
(`letF`/`mapRange`/`shr`) unlocks SHA256 and most Circomlib bit gadgets, `inv`+
`ite` unlock the comparator family, and a `Compilable` story for
`GeneralFormalCircuit`/`FormalAssertion` (37 tops have no entry point today)
plus the AIR layer (track D) are the two design decisions standing between
this backend and the rest.

### A. Close the assurance gaps in this repo

`GAPS.md` is the register; this is the order to take them in, which is not the
order they are written in there.

1. **§4 — done (A1).** `Lookups.lean` and `Test/Lookups.lean`: the lookup half of
   `ConstraintsHoldFlat` has the semantic theorem it lacked, both it and
   `byteTable_lookup_iff` are instantiated at `Addition8FullCarry`, and the
   canonicity hypothesis is discharged from the compiler's own registry and field
   checks rather than assumed — `diagnose_of_mem_registry`,
   `registryOk_of_recognize`, `size_eq_of_recognize`. One hypothesis remains and
   is named: "the compiler accepted this circuit", a `#guard` rather than a `rfl`
   because `recognize` on a real gadget does not reduce in the kernel.
2. **§3 — done (A2).** `Soundness.lean` and `Test/Soundness.lean`:
   `spec_of_compile` is "the emitted module's constraints hold ⇒ the gadget's
   `Spec` holds for its reconstructed `@out{j}` assignment", and
   `add8_spec_of_compile` is it for `Addition8FullCarry`.
   `Operations.FullGuarantees` turned out to be free — it quantifies over channel
   interactions, which `Analyze` refuses — so the chain is A1's lookup theorem
   plus three of Clean's own steps. Soundness direction only; A5 now bridges the
   protected surface to text, while D017's semantics assumption remains.
3. **§1's second half — generic caller-selected identity.** The largest open
   generic-API soundness gap is that an arbitrary caller picks both sides of
   `Certifies`, so it can certify a table the circuit does not look into. The
   current Add8, And8, Xor32, and exact BLAKE3.G headline instantiations are
   separately protected by circuit-specific exact-resolution proofs. Closing
   the API for all callers needs the `Table` to survive into `Lookup` instead of
   being erased to a `RawTable`. That is a change to Clean's core, which since
   R6 is a **gate** — so it is a Clean-side session with its own review,
   reserved by ORCHESTRATION §11, not an increment here.
4. **§6 — done (A4).** Both readers take the expected `Ty` and check it at every
   operand, parameter, member and global; array types are checked exactly against
   the global being read. `Test/Constraints.lean` pins R5e's own counterexample
   going red. It shook out one real defect in the tests: a `#guard` checked every
   corpus module against a hard-coded babybear, which is wrong for five of the six
   `Square_*` entries — `Corpus.Entry` now carries its `FieldSpec`.
5. **§2 — done (A5).** The supported renderer parses all globals, members,
   constraint parameters, and `@constrain` statements back from the concrete
   text, compares them with the typed module, and refuses mismatches before text
   is returned. Both witness backends also compare public-output JSON. The
   theorem and red controls are in `Print.lean` and `Test/Print.lean`. D017
   remains separate.
6. **§5 / D021 — the preservation theorem.** Turning D018's translation
   validation into a verified translator. R5a-4's three obstructions say the
   *reader* has to model the whole emitted function and connect to the active G9
   readers; the old `lower_spec` fragment was retired rather than lifted.
   Largest item in this track and the one with the least leverage
   per hour, because `agree` already refuses a wrong module.
7. **§8 — done (A7).** `CopyCanon.step_preserves` proves that one
   canonicalisation step preserves the semantic representative invariant, and
   `run_preserves` lifts it across the whole witness-program list.
   `WitnessSet.ofSource` uses that `run` rather than a mutable update. Together
   with `WExpr.eval_rename` and `WExpr.eval_congr`, the copy-collapse argument no
   longer has an inspection-only premise. The theorems use only `propext` and
   `Quot.sound`; the probe is in `evidence/A7/`.

### B. CI — **done, and it was already done**

`alexanderlhicks/clean` PR #1, open since 2026-08-02, and CI green on it at
`4e15d3ad`: `build`, `llzk-harness`, `llzk-e2e`, `plonky3-backend`. The workflow
is not untested code and `nix build …#llzk` does work on a runner. See
"Reproduce everything" above for how this document managed to say otherwise for
two days, and what R6 should have done about it.

What remains is upkeep rather than a decision: keep the PR current, and treat a
red run as a gate like any other.

### C. Stage 2 — capability

In dependency order, each an increment of the shape D009 describes (one
`FieldExpr` constructor, one recognizer case, one `lower` case, one positive and
one negative fixture):

- **Bounded structural u64 first** — **S26, implemented locally**. D033 admits
  only expressions whose syntax proves every result canonical and every `.val`
  exact; `bitsOf` lowers directly. This removes `And8`'s `land` refusal and adds
  lookup-free `LowByte`/`Bits8` corpus entries, while correctly retaining XOR
  rows whose range evidence is outside witness IR.
- **Multi-column tables** (D013 superseded by D034) — **S28, accepted locally**.
  Ordered `array.new` rows, multi-dimensional
  `constrain.in`, row-preserving G9, and certification at 65536×3 unlock `And8`.
- **A range contract visible to witness lowering** — **S29 Phase B, implemented
  locally**. Executable source narrowing plus proved generic modulo/XOR/OR
  bounds now compile narrowed Xor32 and the checked BLAKE3.G instantiation
  without using `FormalCircuit.Assumptions`. Raw-XOR Keccak remains refused,
  Xor32 has external-corpus promotion evidence on `06b80f2f`, and exact
  BLAKE3.G `G 0 1 2 3` on `a3299ca0`.
- **The rest of the witness IR**: `let`-steps and `mapRange` → `scf.for` (this
  is SHA256's real blocker, R7-07, and the zkGolf Add32 ports' too, R7-09),
  `inv` → `felt.inv` (with `ite`, the `IsZero`/comparator family), `listGet` →
  the array dialect.
- **A `Compilable` story beyond `FormalCircuit`** — `GeneralFormalCircuit`,
  `FormalAssertion` and `LookupCircuit` tops (28 in `Gadgets`+`Circomlib`)
  cannot reach `compile` at all today; R7-07 found the coverage table silently
  excluded them. Whether each gets an instance, an adapter, or a documented
  refusal is a design decision to record, not code to sneak in.
- **Subcircuits as named components** alongside `@Main`. This is the shape D015
  was chosen to be compatible with. A scaling concern rather than a capability
  one.
- **The remaining natural/control-flow IR**: dynamic divisors/shifts, `idx`,
  `localVar`, and `ite` still need loop, let, and control-flow policies.

### D. The AIR layer — an unfaced design decision

Clean's `Clean/Table/*` is genuine AIR: a trace of rows with
`EveryRow`/`EveryRowExceptLast`/`Boundary` transition constraints. **LLZK has no
analogue**, and Stage 1 and Stage 2 both sidestep it by compiling a single
flattened circuit. Prior art to copy rather than invent: the
`airbender-llzk-frontend` tree lowers AIR traces and lookups to LLZK. This is the
largest unscoped question in the project and it is not on any track above.

### E. VeIR — parallel, non-blocking

D003 holds: VeIR consumes the frozen `.llzk` fixture corpus rather than being a
dependency. Its separately tracked readiness plan has workstreams W0–W8 and
milestones VM1–VM4; `GAPS.md` §7 (D017 has no formal basis) is the gap only VeIR
can close, because closing it means formalising LLZK.

### Recommended order

**A1, A2, A4, A5, A7, B, S25, and L0 are done.** S25 fetched and merged the
unchanged `0e53b9f2` head, preserved the narrow accepted subset, and made
Deliverable 2a visible as D026 rather than letting green gates hide the weakened
theorem domain. L0 advanced the LLZK input to exact SHA `25fb3740` after the old
and new tools passed the unchanged same-tree matrix. **S26 is implemented
locally**: D033, structural lowering, direct `bitsOf`, proofs, corpus, and
remeasured coverage are in place. **S28 is green on its clean implementation
commit**, and **S29 Phase B has completed the witness-visible Xor32/BLAKE3.G
range contract on `7a0f209c`**. **Xor32 promotion is complete on `06b80f2f`,
and exact BLAKE3.G promotion on `a3299ca0`;** this documentation-only closure
completes S29. The first frozen R8 candidate `c60d8363` was rejected; repair and
a full R8 restart are in progress, while the witness-IR loop increment remains
later. S27
remains returned for re-scoping (R7-09).

The assurance track's A5 renderer and A7 copy-canonicalisation items are now
done: the on-disk constraint surface has the second line of defense R7-02 called
for, and the copy-collapse premise is proved rather than inspected. Its next
independent backend item is A6 (the preservation theorem, D021). A3 is more
important but is a Clean-core session, so it should be *scheduled* rather than
slipped into a backend increment — and G0 now enforces that, including against
uncommitted edits (R7-01).

One process item, from B: **check the world, not the document.** Track B was on
this list at all because three sessions in a row read a paragraph saying CI had
never run, and none of them ran `gh run list`. Any claim here about GitHub, the
LLZK toolchain, or anything else outside the worktree should be re-checked
against the thing itself before it is planned around.
