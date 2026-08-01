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

## G2–G4 — emit and check the corpus

```bash
# Emit the corpus to a directory. Runs under the Lean interpreter, so it needs
# only the oleans `lake build Clean` already produces -- no native compilation.
lake env lean --run Clean/Backend/LLZK/EmitMain.lean <output-directory>

# Everything above, plus llzk-opt parse and round trip on every artifact.
LLZK_OPT=... LLZK_WITGEN=... bash scripts/llzk/e2e.sh
```

There is deliberately no `#emit_llzk` macro. `#eval IO.print (LLZK.emit cfg
"Name" circuit)` already does that job — the golden tests use exactly that form —
and the artifact-producing command is the executable above, which is what a
harness needs.

`e2e.sh` fails closed. A missing tool, a tool that is not executable, or a tool
whose `--version` does not mention the pinned LLZK version is an error, never a
skipped check. The version check is not ceremony: an LLZK 2.0 `llzk-opt` is
installed on this machine and accepts different syntax, so a bare existence
check would silently validate against the wrong language.

Set `LLZK_EXPECTED_VERSION` when the LLZK pin moves; it is the single place the
version appears.

## G5–G7 — witness generation, differentially

`LLZK.Corpus.corpus` carries input vectors alongside each circuit. The emitter
writes, per vector, the `--inputs` object and Clean's own witness for it, in the
shape `--output-scope=full-witness --check-output` compares against. Clean's side
uses `FlatOperation.witgen`, the array-backed reference interpreter that
`witgen_eq_dynamicWitnesses` proves agrees with the semantic definition.

So G7 is not a separate run: `--check-output` carries it inside G5 and G6, and a
disagreement is a non-zero exit rather than two JSON dumps to compare by eye.

Key names come from `Circuit.lean`'s layout functions, shared with the emitter,
so the expected JSON cannot drift from the emitted members.

**What G5–G7 do not establish.** `llzk-witgen` executes `compute()` and ignores
`constrain()`. Agreement means the two witness generators agree; it says nothing
about whether the emitted constraints capture Clean's. That is the G9 proof
track.

Keep these gates falsifiable. A green that cannot go red is decoration — S02
verified both by corrupting an expected value and by injecting a one-off into
Clean's witness computation. Note that editing a generated file in place is *not*
a valid check: `e2e.sh` removes and regenerates its output directory every run.

## Evidence

Store concise evidence under `doc/llzk/evidence/SNN/`. Record:

- complete command;
- tool version;
- exit status;
- relevant output or result artifact;
- integration commit being tested.

Evidence that exists only in `/tmp` is not accepted.

