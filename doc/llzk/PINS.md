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

## Clean repository

- Fork: `git@github.com:alexanderlhicks/clean.git`
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

- Store path: `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0`
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

