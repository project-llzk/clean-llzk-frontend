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

S01 must fill in:

- reproducible acquisition/build command;
- absolute or repository-relative tool location;
- `llzk-opt --version` output;
- `llzk-witgen --version` output;
- evidence that both tools correspond to the pinned LLZK revision.

An installed LLZK 2.0 `llzk-opt` is not an acceptable substitute.

