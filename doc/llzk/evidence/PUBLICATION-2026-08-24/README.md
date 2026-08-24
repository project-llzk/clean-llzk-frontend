# Hosted-CI portability recovery

Transaction opened: 2026-08-24 Europe/London

Exact-candidate verification completed: 2026-08-25 Europe/London

This directory records the local, pre-push qualification of the fail-closed
hosted-CI portability recovery. It does not claim that hosted CI has recovered:
that claim requires a new automatic `push` run on the exact documentation child
that becomes `main`, followed by the separately authorized exact-candidate
dispatch.

## Commit identities and scope

The identities are deliberately distinct:

- `193ec342cb2aae9055c36f4f77d2a4fe23da7823` remains the semantic R8 code
  candidate whose theorem, renderer, and Plonky3 false-green repairs were
  reviewed in `../R8-2026-08-23/`. Relevant source, backend, workflow, Plonky3,
  and theorem trees transfer byte-for-byte; they were not relabelled as fresh
  reproductions here.
- `03150549adebd1ef4d83d1415bdcd117e9887493` is the publication-bootstrap
  documentation tip currently on remote `main` before this transaction.
- `34afda59cf5709b6e4c5c8081db4b2e31322c52a` is a rejected sibling candidate.
  It escaped a hidden `.attack.yml` because the first grep port did not include
  dotfiles. It remains preserved off the selected ancestry.
- A later hand-written Python/YAML-parser draft was discarded before sealing.
  It was never committed and was never a candidate.
- `f6ef1331ee860a2395d7058025da488e2553a390` is the tested portability-recovery
  candidate C. Its sole parent is `03150549`; its tree is
  `9c58c9ed17fda6105c72cf5ef5bb8a12b10c4c0f`.
- The commit containing this evidence is documentation/evidence child D. It is
  not the matrix-tested code candidate, and cannot contain its own commit SHA.

C changes exactly two executable assurance scripts:

| Path | Insertions | Deletions | SHA-256 at C |
|---|---:|---:|---|
| `scripts/llzk/check-actions-pinned.sh` | 173 | 36 | `62f8126d40d2d1dd09ea4f78a5223d5254a62f50e270c2d3535e7682c69fca2d` |
| `scripts/llzk/test-scripts.sh` | 177 | 7 | `449d2b4f441c1bddbe02f5ee84179da781e1f19f16adcb2def5b9e3981920f6a` |

No Clean/source, frontend backend, workflow, Plonky3, build-manifest,
benchmark, profile, visibility, or GitHub-setting change is part of C. The
sealed patch digest against `03150549` is
`d858e0ef1bcc48f5e31a6dafb161060dc497ace96612c434cf9207651263c81a`.

## Repair design

All 17 executable ripgrep calls were removed: ten in the action checker and
seven in its harness. `grep` is now a named dependency, and each scan
distinguishes honest no-match from an execution/read error. `sha256sum` is also
a named dependency.

The generic checks are intentionally only line-oriented tripwires; they do not
claim to parse YAML. For the load-bearing invocation where the supplied
directory resolves to this checker's own `.github/workflows`, the checker first
requires this exact four-path/four-hash manifest:

| Workflow | SHA-256 |
|---|---|
| `bench-command.yml` | `eb2994c0f0c914d368bd006b663f11401b033b9f4a7b7d73b02729d4aefed29f` |
| `bench-main.yml` | `6485c6359e5e57875afe5d6fe498a805c7b3200517629a6abbdbb58e2b8be9fc` |
| `bench.yml` | `32041bf71398add49a5bad144c821c80592f85747301fa054ae73176d55843fa` |
| `ci.yml` | `5bbccdb4b6da9cb5c3522d07e5b988f10ebcbc11c094915ef28b9f95346af9ef` |

That manifest fails on missing, renamed, extra, hidden, nested, symlinked,
nonregular, unhashable, or byte-changed workflow paths. Arbitrary caller-supplied
directories retain the generic tripwires without being misrepresented as exact
repository-manifest checks. Permanent red controls cover both layers, including
missing tools, failing primary and secondary grep calls, and `sha256sum`
execution failure. The exact C harness reports 201 error paths.

## Execution ledger

All captures ran from a clean `f6ef1331` worktree while
`LLZK_SESSION=publication-execution-20260824-root` held the advisory lock.
Pre- and post-capture `git rev-parse HEAD` returned exact C and
`git status --porcelain=v1` was empty. Each pipeline used `bash -o pipefail`; all
four commands exited 0.

Accepted LLZK (`25fb3740ea3465c9129a06289297bb4f0554b7a5`):

```bash
bash -o pipefail -c '
  env LLZK_SESSION=publication-execution-20260824-root \
    LLZK_OPT=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin/llzk-opt \
    LLZK_WITGEN=/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin/llzk-witgen \
    bash scripts/llzk/e2e.sh 2>&1 | tee /tmp/f6ef1331-accepted-matrix.log
'
```

Checked LLZK main (`b5c110d1088e93d6786f66ec1e155be87bae755f`):

```bash
bash -o pipefail -c '
  env LLZK_SESSION=publication-execution-20260824-root \
    LLZK_OPT=/nix/store/hvvbkw0afshj37zpiilw0jwxjxfad4p4-llzk-release-3.0.0/bin/llzk-opt \
    LLZK_WITGEN=/nix/store/hvvbkw0afshj37zpiilw0jwxjxfad4p4-llzk-release-3.0.0/bin/llzk-witgen \
    bash scripts/llzk/e2e.sh 2>&1 | tee /tmp/f6ef1331-checked-main-matrix.log
'
```

Plonky3 ran from `backends/plonky3`:

```bash
bash -o pipefail -c '
  bash ../../doc/llzk/evidence/R8-2026-08-23/plonky3-command.sh.txt \
    2>&1 | tee /tmp/f6ef1331-plonky3.log
'
```

The command file hashes to
`a87a387aec4615441dbc953ee1736e1a40609312fcdd5da738e47116416cc339`
and is byte-equal to the current `ci.yml` Plonky3 run block. It asserted exact
registered names and counts before running one Fibonacci, two debug-negative,
two release-negative, and two FemtoCairo tests. Every result reported zero
failed, ignored, or filtered tests.

The poison run exported a shell function that would print the named marker and
return 97 on any `rg` invocation:

```bash
bash -o pipefail -c '
  function rg { echo "POISON: ripgrep invocation" >&2; return 97; }
  export -f rg
  bash scripts/llzk/test-scripts.sh 2>&1 | tee /tmp/f6ef1331-poison-rg.log
'
```

The transcript has one terminal `PASS: 201 error paths exercised` and zero
poison markers. A separate static scan found no executable `rg` reference in
either changed script.

## Raw evidence and results

| Artifact | SHA-256 | Lines | Bytes |
|---|---|---:|---:|
| [`accepted-matrix.txt`](accepted-matrix.txt) | `17057d9f4ae3a0dc9ee50ce18022169710a2abad86ae1dbae9c81bc423602c85` | 571 | 30,765 |
| [`checked-main-matrix.txt`](checked-main-matrix.txt) | `452af714867d99bd7df0a600f3aa1aeb5965236275bcf9ece24ae79a8b6df7fd` | 571 | 30,765 |
| [`plonky3.txt`](plonky3.txt) | `e91fcc24b433561fc48061b549a4ff3b749b216eaf08822ee5b6e44c086562f1` | 43 | 2,127 |
| [`poison-rg.txt`](poison-rg.txt) | `5cfa089daa594f4dcd90f51dd9ab7e36976d3facd69f9f10edb639770d908b0c` | 214 | 11,288 |

`plonky3.txt` preserves the raw capture's final blank line. That scoped
transcript whitespace is part of the reviewed 43-line/2,127-byte artifact and
its recorded hash; it is not normalized or silently rewritten for document
style.

Each matrix contains exact C in G0, one G11 PASS at 201, one action-policy PASS
at 15 references, 17 corpus G3/G4/G10 paths, two renderer fixtures, 67
interpreter and 67 execution-engine vectors using both output scopes, 19/19
product-program admissions, 10 SMT lowerings, nine declared exclusions, 17
terminal module `ok` lines, and one terminal G0-G12 PASS. The only warnings are
the ten inherited `Clean.Utils.Test.TestCircuitProofStart` `sorry` declarations.
An anchored scan found no unexpected FAIL, error, fatal, panic, abort, timeout,
or termination.

The two raw matrices differ only in the expected `LLZK_OPT` and `LLZK_WITGEN`
store-path lines. Normalizing those two store roots makes both full streams hash
to `2407f8b7ef15ecb31065e1e47aa0f78c2394e479c3b7ca66a7976333b54b122c`.

## Remote boundary before push

Read-only checks found repository ID `1345370888` at
`https://github.com/project-llzk/clean-llzk-frontend`. It is intentionally
Public by explicit owner decision and must remain Public. Before D is pushed,
its only branch is `main` at `03150549`; C is not present remotely.

During D review, repository `updated_at` advanced to
`2026-08-24T23:31:41Z` while `pushed_at`, refs, runs, settings, teams, and
collaborators remained unchanged. The public event stream resolves that drift:
WatchEvent `13793717639` records actor `bwcummings1` starting a watch at
`23:31:40Z`. This is observed public interest, not a repository-content,
configuration, or transaction mutation.

The only runs are the original bootstrap runs at exact `03150549`, attempt 1:

- CI `32773834028`: `event=push`, completed failure. The dependency-pin and G11
  steps failed with `rg: command not found`; LLZK e2e and Plonky3 were skipped.
- Bench Main `32773834126`: `event=push`, skipped because
  `CLEAN_BENCH_ENABLED` remains absent.

Current observed settings are boundaries, not completed publication work:
`main` is unprotected; private vulnerability reporting is disabled; Dependabot
security updates, secret scanning, and push protection are disabled; Actions
is enabled for all actions, workflow permissions are read-only, and PR approval
is disabled; action-SHA pinning policy is not enforced by GitHub; the benchmark
variable is absent. Direct collaborators are empty; inherited `Maintainers` and
`core-devs` teams both have maintain access. Issues are enabled; projects,
wiki, and discussions are disabled. Squash, merge-commit, and rebase strategies
are all enabled; auto-merge and automatic branch deletion are disabled.
This transaction does not authorize changing those settings, organization
policy, visibility, profile, workflows, or benchmarks.

The remaining authorized sequence is fail-closed:

1. Seal this documentation/evidence-only sole child D of C.
2. Re-read the remote and make one explicit non-force fast-forward of D to
   public `main`.
3. Accept only the newly registered automatic `event=push`, attempt-1 CI run
   whose exact head SHA is D and whose four jobs all succeed. A rerun, parent
   run, dispatch, or synthetic merge SHA does not substitute.
4. Only then push exact C under `r8-code-candidate-f6ef1331`, verify the ref,
   and dispatch `ci.yml` once. Accept only that exact candidate SHA/event/run.
5. Stop on any mismatch, failed job, duplicate attempt, unexpected remote
   change, or missing run. No force push is permitted.

The temporary `/tmp` R1CS/WTNS feasibility probe is outside this recovery. It
is not repository-gated evidence and is not attributed to C.
