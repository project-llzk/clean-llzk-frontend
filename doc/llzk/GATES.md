# Clean → LLZK acceptance gates

Every session packet names the gates it must pass. Review sessions rerun the
accumulated gates from a clean checkout.

| Gate | Meaning |
|---|---|
| G0 — State | Correct worktree/branch, exact pins, clean or documented status |
| G1 — Lean | Targeted Lean compilation/tests; broader build when required |
| G2 — Golden | Deterministic text equals the reviewed fixture |
| G3 — LLZK verify | Pinned `llzk-opt` parses and verifies |
| G4 — Round trip | Pinned `llzk-opt --verify-roundtrip` succeeds |
| G5 — Interpreter | Pinned witgen interpreter produces the expected witness |
| G6 — Execution engine | Pinned execution engine produces the same witness |
| G7 — Differential | Clean and LLZK witnesses agree on the fixture corpus |
| G8 — Fail closed | Unsupported constructors and invalid layouts diagnose |
| G9 — Proof | Named theorem target builds without new `sorry` |

## G0 — State

```bash
bash scripts/llzk/check-pins.sh
bash scripts/llzk/doctor.sh                  # adds tool discovery
bash scripts/llzk/doctor.sh --require-llzk   # fails if LLZK tools are missing
```

## G1 — Lean

G1 is defined as the checks `.github/workflows/ci.yml` runs, so that a green
gate means a green CI. A session running G1 against the whole library runs all
three; a session touching only backend modules may run the targeted form
(`lake build --wfail Clean.Backend.LLZK`) plus the lint, and must say so in its
evidence.

```bash
python3 scripts/check-consecutive-empty-lines.py
lake build --wfail Clean
lake build CleanTests
```

`lake build CleanTests` is deliberately not run with `--wfail`: the test library
carries pre-existing `declaration uses 'sorry'` warnings at the pinned base
(`Clean/Utils/Test/TestCircuitProofStart.lean`), and CI does not gate on them
either. Backend test modules must not add new ones — G9 covers that.

S01 records exact LLZK commands and paths here. S02 adds the golden-fixture
commands. Later sessions extend `scripts/llzk/e2e.sh`; a missing required tool
must fail rather than skip.

## Evidence

Store concise evidence under `doc/llzk/evidence/SNN/`. Record:

- complete command;
- tool version;
- exit status;
- relevant output or result artifact;
- integration commit being tested.

Evidence that exists only in `/tmp` is not accepted.

