# Clean → LLZK pins

These revisions are the accepted inputs to the initial implementation. Pin
updates require an explicit session and decision-log entry.

| Component | Revision | Role |
|---|---|---|
| Clean | `1e563b9c27991b3795eb440c1ee0757edb4ce8b1` | Frontend host and source semantics |
| LLZK | `5db6f8f9baaa40787a1a40625796497445f2da36` | LLZK 3.0 syntax, verifier, and witgen reference |
| project-llzk VeIR | `eae1c27e7842c0503233ec99155c39791bd5f502` | Existing LLZK-aware VeIR fork |
| upstream VeIR | `a4e6194d5810a02d74f0094ff6014cda6db6d617` | Long-term Lean MLIR framework |
| llzk-lean VeIR | `d899d95004d4bd988c8456d686c33b11a7a5eb4a` | Previously accepted differential harness pin |

Public-readiness note (checked 2026-08-21): `project-llzk/llzk-lib` `main` is
`25fb3740ea3465c9129a06289297bb4f0554b7a5`, 25 commits ahead of the accepted
LLZK pin. The changed surface includes core transforms, analysis,
`llzk-witgen`, and downstream backends. There is no newer tagged GitHub release
than v2.1.2 even though the pinned build identifies itself as LLZK 3.0.0, so a
tag comparison is not a sufficient update policy. L0 in
`PUBLIC-READINESS.md` will either retain this known reproducible pin or advance
it through a separate full-gate compatibility session. Its read-only delta
inventory and same-tree decision procedure are prepared in
`sessions/L0-review-llzk-pin.md`. Until that decision, the table above remains
authoritative.

## CI execution environment

Workflow dependencies are repository inputs too. `scripts/llzk/check-actions-pinned.sh`
rejects mutable action tags, moving `ubuntu-latest` runners, an implicitly enabled
self-hosted workflow, or a non-read-only token default. The reviewed action commits
are:

| Action | Commit | Reviewed release line |
|---|---|---|
| `actions/checkout` | `11d5960a326750d5838078e36cf38b85af677262` | v4 |
| `leanprover/lean-action` | `38fbc41a8c28c4cbaec22d7f7de508ec2e7c0dd9` | v1 |
| `cachix/install-nix-action` | `ba0dd844c9180cbf77aa72a116d6fbc515d0e87b` | v27 |
| `actions/upload-artifact` | `ea165f8d65b6e75b540449e92b4886f43607fa02` | v4 |
| `actions/github-script` | `f28e40c7f34bde8b3046d885e986cb6290c5673b` | v7 |
| `actions/cache` | `0057852bfaa89a56745cba8c7296529d2fc39830` | v4 |
| `dtolnay/rust-toolchain` | `4360b52568e2003a75bf9bc1d59f33a8e3fc893c` | stable action |

GitHub's commit API reported a verified signature for each commit when reviewed
on 2026-08-21. Release names in comments are review labels; the full commit SHA
is the executable authority. Hosted jobs use `ubuntu-24.04`. The Plonky3 job
requests Rust `1.98.0`, the stable release in the official 2026-08-20 manifest,
rather than following the action's moving `stable` default.

The LLZK job installs the exact `veridise-public.cachix.org` substituter and key
recorded below, then builds with `--max-jobs 0`. The accepted output was present
in that public cache during S01, so CI downloads it or fails; it cannot silently
turn a missing substitute into a multi-hour LLVM source build. The first run of
the frozen candidate in the organization repository must still demonstrate
that the cache remains anonymously readable there.

The self-hosted benchmark workflows are deliberately excluded from the normal
release gates and require `CLEAN_BENCH_ENABLED == 'true'`. Keep that repository
variable unset until the runner boundary described in `PUBLICATION.md` has a
named owner and a separate threat review.

## Clean repository

- Development staging fork: `git@github.com:alexanderlhicks/clean.git` (not the
  public destination; D027)
- Upstream: `git@github.com:Verified-zkEVM/clean.git`
- Integration branch: `clean-to-llzk/integration`
- Lean toolchain: `leanprover/lean4:v4.30.0`

The Clean revision is a base pin: frontend commits descend from it. The pin
checker rejects a history that no longer contains it.

## LLZK tools

Provisioned by S01. Evidence: `doc/llzk/evidence/S01/tools.txt`.

```bash
nix build --no-link --max-jobs 0 --print-out-paths \
  github:project-llzk/llzk-lib/5db6f8f9baaa40787a1a40625796497445f2da36#llzk
```

- S01 evidence-machine output:
  `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0` (provenance,
  not a portable path)
- `LLZK_OPT` = `<that>/bin/llzk-opt`, reports `LLZK version 3.0.0`
- `LLZK_WITGEN` = `<that>/bin/llzk-witgen`

Entirely substituted from `https://veridise-public.cachix.org`; nothing built
from source. Keep `--max-jobs 0`: it turns a substitution failure into an error
rather than a silent multi-hour LLVM build, which is exactly the failure mode
that cost this project a session.

`llzk-witgen --version` reports only LLVM's version and never mentions LLZK, so
`scripts/llzk/lib.sh` establishes its provenance by requiring it to sit in the
same directory as a version-checked `llzk-opt`.

An installed LLZK 2.0 `llzk-opt` is not an acceptable substitute, and the
scripts reject it by version — verified.

### Cache key

`/etc/nix/nix.conf` must carry the *correct* public key for the substituter:

```
extra-substituters = https://veridise-public.cachix.org
extra-trusted-public-keys = veridise-public.cachix.org-1:FvpZ8GzAj1mmJA5PnO9UgKxC6CQdmPutuIKtEpGmeig=
```

A wrong key is worse than a missing one: Nix selects it by name, fails
verification, discards the substitute, and falls back to building from source
without saying why. `nix-daemon` reads this file only at startup, so a change
needs `sudo systemctl restart nix-daemon`. See
`doc/llzk/evidence/S01/substituter-diagnosis.md`.
