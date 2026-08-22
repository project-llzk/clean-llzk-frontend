# Clean → LLZK acceptance gates

Every session packet names the gates it must pass. Review sessions rerun the
accumulated gates from a clean checkout.

| Gate | Meaning |
|---|---|
| G0 — State | Correct worktree/branch, exact pins, clean or documented status |
| G1 — Lean | Targeted Lean compilation/tests; broader build when required |
| G2 — Renderer | Deterministic text equals the reviewed fixture; globals, members, parameters, and the complete constraint body parse back to the typed IR |
| G3 — LLZK verify | Pinned `llzk-opt` parses and verifies |
| G4 — Round trip | Pinned `llzk-opt --verify-roundtrip` succeeds |
| G5 — Interpreter | Pinned witgen interpreter produces the expected witness |
| G6 — Execution engine | Pinned execution engine produces the same witness |
| G7 — Differential | Clean and LLZK witnesses agree on the fixture corpus |
| G8 — Fail closed | Unsupported constructors and invalid layouts diagnose |
| G9 — Semantics | The emitted `@constrain` and `@compute` are the circuit's |
| G10 — Pipeline | Every artifact is admissible to LLZK's analysis pipeline |
| G11 — Harness | The scripts' own failure branches behave as written |
| G12 — Confinement | Every entry point that skips a gate is confined to the modules with a reason to name it |

## G0 — State

```bash
bash scripts/llzk/check-pins.sh
bash scripts/llzk/doctor.sh                  # adds tool discovery
bash scripts/llzk/doctor.sh --require-llzk   # fails if LLZK tools are missing
```

G0 distinguishes upstream Clean provenance U from the accepted local Clean
overlay K. It requires both immutable commits, K as U's direct single-parent
child, the exact reviewed `M Clean/Gadgets/Xor/Xor32.lean` U..K delta, K as an
ancestor of HEAD, and byte identity of all later Clean core outside the backend
and its two registration files. It separately rejects uncommitted core drift.

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

The full `e2e.sh` form of G1 also generates `doc/llzk/EXAMPLES.md` from
`LLZK.Corpus.corpus` through `ShowcaseMain.lean` and requires byte equality with
the checked-in page. `Test/Showcase.lean` pins the corpus denominator, ordering,
vector total, source-agreement count, and editorial coverage. Public example
counts are therefore executable documentation rather than a second source of
truth.

## G2–G4 — emit and check the corpus

```bash
# Emit the corpus to a directory. Runs under the Lean interpreter, so it needs
# only the oleans `lake build Clean` already produces -- no native compilation.
lake env lean --run Clean/Backend/LLZK/EmitMain.lean <output-directory>

# Everything above, plus llzk-opt parse and round trip on every artifact.
LLZK_OPT=... LLZK_WITGEN=... bash scripts/llzk/e2e.sh
```

The emitter also writes `<output-directory>/syntax/`: the renderer fixtures from
`Clean/Backend/LLZK/RendererFixture.lean`, which have no Clean circuit behind
them and no input vectors. G3/G4 run over them. That is the repair for R2-04 —
the renderer golden had never been shown to a tool and was in fact invalid LLZK,
while its own docstring claimed `e2e.sh` fed it to `llzk-opt`.

Since A5, `Module.render` is itself fail-closed. S28 extends its independent
readback to `global.def` and `array.new` alongside `struct.readm`,
`constrain.eq`, and `constrain.in`, so table dimensions, row-major values, row
construction, and membership are compared with the typed module before text is
returned. The round-trip
theorem is `Module.render_constraintSurface`; `Test/Print.lean` pins direct
parses and red mutations, including member aliasing, dropped constraints,
changed row grouping, malformed row construction, and wrong row field types.
Thus G2 covers semantic constraint/table-surface drift as well as byte drift.

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
writes, per vector, the `--inputs` object and a checked expected full/public
witness. Historical entries derive it from Clean. Promoted reference-backed
entries carry fixed independent public results which must equal Clean before
they replace the public fields in both JSON scopes. Both LLZK backends compare
both
`--output-scope=full-witness` and `--output-scope=public` with `--check-output`.
The public check is separate because full-witness JSON groups signal and public
members together and cannot detect a visibility mistake. Clean's side uses
`FlatOperation.witgen`, the array-backed reference interpreter that
`witgen_eq_dynamicWitnesses` proves agrees with the semantic definition.

So G7 is not a separate run: `--check-output` carries it inside G5 and G6, and a
disagreement is a non-zero exit rather than two JSON dumps to compare by eye.

Key names come from `Circuit.lean`'s layout functions, shared with the emitter,
so the expected JSON cannot drift from the emitted members.

**What G5–G7 do not establish.** `llzk-witgen` executes `compute()` and ignores
`constrain()`. Agreement means the two witness generators agree; it says nothing
about whether the emitted constraints capture Clean's. That is G9.

Keep these gates falsifiable. A green that cannot go red is decoration — S02
verified both by corrupting an expected value and by injecting a one-off into
Clean's witness computation. Note that editing a generated file in place is *not*
a valid check: `e2e.sh` removes and regenerates its output directory every run.

Since S09 the harness does not take that on trust. S29 strengthens the
discriminator across both scopes: each backend must accept the original
expectation and reject independent numeric first, middle, and last field
mutations in the full-witness and public JSON. The probes include both corpus
endpoints and the artifact selected from emitted JSON as having the widest
public interface. Xor32 additionally checks every one of its four outputs in
both scopes on all three compute-only rows. Its both-wide row must reject the
exact old raw-XOR full witness and public result, presented under PID-derived
non-raw scratch names. BLAKE3.G's lane-marker row additionally pins exact
72-input/96-witness/64-output layouts and perturbs every one of its 96 witness
cells and 64 outputs independently in both backends; outputs are checked in
both full and public scopes. G11 has separate partial-checker attacks that
validate only `w0` or `out0`, omit Xor32 `out1`, ignore BLAKE3.G `w42`, accept
the raw full/public alternate, or specialize on predictable paths.
R2-06 showed why this is necessary: with `llzk-witgen` replaced by a two-line
`exit 0` script sitting next to a symlinked `llzk-opt`, the harness reported
PASS and exited 0. Provenance by co-location was necessary and not sufficient;
what the gates need is that the binary discriminates across both scopes and the
witness-cell/full-output/public-output groups at the sampled first, middle, and
last positions.

## G9 — the emitted constraints

```bash
lake build CleanTests        # Test/Constraints.lean and Test/WitnessCheck.lean
```

Runs at Lean compile time and is also enforced by the emitter: `EmitMain` refuses
to write a corpus entry whose constraints disagree, so `e2e.sh` carries it too.

`Clean/Backend/LLZK/Constraints.lean` reads the Clean circuit and the emitted
module into the same canonical polynomial form, through two readers that cannot
see each other's input, and compares them as multisets. See D017 for what that
proves and what it assumes.

This is the gate R2's Control 4 was missing. An `Addition8FullCarry` module with
a completely empty `@constrain` passes G3, G4, G5, G6, G7 and G10 on all six
input vectors; it does not pass G9.

Falsifiability is part of the gate rather than a note about it:
`Test/Constraints.lean` perturbs the Clean side — dropping a constraint, bumping
a coefficient, duplicating a constraint, dropping the lookup, substituting
another circuit — and pins that the comparison goes red for each. S28 adds
row-specific controls: splitting a row into scalar memberships, swapping
columns, and regrouping a global without changing its flattened scalar bag.

**G9 is not a property of the corpus.** Since S17 the comparison is a
*precondition of emission*: `ConstraintSet.compileSource'` runs it and refuses to
return a module that fails, and `compile`/`emit` go through it.
`agree_of_compileSource'` is the theorem, `witnessAgree_of_compileSourceVerified`
its witness-side counterpart, and `eqs_iff_of_agree` plus
`lookups_perm_of_agree` give the constraint agreement its semantic meaning. So
this holds for every circuit, not only for the circuits in the corpus.

This paragraph used to say `compile`/`emit` were "the only public entry points".
D018 retracted that in the R4 round and this file was not updated, so R5 found
the retracted claim still standing here. The accurate statement is the one above:
**no module obtained through `compile` or `emit` has gone unchecked.** Other
public entry points return a module without both halves — `compileSource`,
`compileSource'`, `lowerRecognized` — and G12 confines them to the modules with a
reason to name them, none of which is reachable from ordinary circuit code.
`Module.render` is public too, and G9 compares `Module`s rather than text; see
the renderer entry in `GAPS.md`.

That is translation validation rather than a verified translator: a lowering bug
would surface as a refusal to compile rather than as a compile-time
impossibility. The 2026-08-22 audit retired the unused `FieldExpr.lower_spec`
fragment after R5a showed that it neither composed nor excluded grossly wrong
lowerings. `GAPS.md` item 5 records the requirements for a future whole-translator
proof.

**G9 has two halves, and both are preconditions of emission.**
`Constraints.lean` compares `@constrain` against the circuit's constraints;
`WitnessCheck.lean` (S19) compares `@compute` against its witness programs, with
`WExpr.eval_ofWitgen` proving that the Clean-side reading is `Witgen.FExpr.eval`.
`compile` and `emit` live in `WitnessCheck.lean` and go through both.

Since A7, the copy-collapse needed by the witness reader has no
inspection-only premise: `CopyCanon.step_preserves` proves one extension and
`run_preserves` proves the invariant across the whole witness-program list;
`ofSource` uses that proved `run` directly. Copy chains and computed non-copies
remain pinned in `Test/WitnessCheck.lean`.

**What G9 does not establish.** D017's reading of the emitted IR: that `felt.add`
is `+`, `constrain.eq` is equality, `constrain.in` is membership, and natural,
bitwise, and shift operations read their operands as canonical representatives.
Nothing in Lean settles that without a formal model of LLZK; G5–G7 are the
empirical evidence for the `@compute` half of it, on 67 vectors (61 from Clean
sources) and two independent LLZK backends; S26 also probes every new operation spelling
directly. The lookup *rows* used to be listed here; since S16
they are proved — see D012 and `Clean/Backend/LLZK/TableCert.lean`.

## G10 — the LLZK analysis pipeline

```bash
llzk-opt --llzk-full-inlining --llzk-product-program <artifact>          # G10a
llzk-opt --llzk-full-inlining --llzk-product-program \
         --llzk-to-smt-no-cf <artifact>                                 # G10b
```

**G10a — admissibility — must succeed on every artifact, with no exceptions.**
`--llzk-product-program` is the entry point to the SMT lowering and to everything
downstream of it, and it looks up a root struct named literally `Main`, ignoring
`llzk.main`. Before S12 the emitter named the component after the circuit, so no
emitted module could enter any LLZK analysis and no gate noticed (R2-12, D015).

**G10b — SMT lowering — is tolerated to fail only for a reason declared in
`lib.sh`**, matched against the tool's own diagnostic rather than against what the
artifact contains. The tolerance list holds only reasons a corpus artifact
actually produces, because a tolerance nothing exercises can only ever excuse
something. At the LLZK 3.0.0 pin those are natural and bitwise/shift felt
operations, which the lowering marks illegal, and a module with no felt type,
whose prime field cannot be deduced. Both sides of the split are exact gates,
not floors: at the BLAKE3.G promotion boundary, ten of the nineteen
corpus-plus-fixture modules lower and nine are out of scope for exactly those
declared reasons.

**The solver step is not reachable from the pinned tools.** `llzk-smt-check`
ships in the same `bin/` and takes SMT-LIB, and `llzk-translate --smt-to-smtlib`
requires a top-level `smt.solver` op that none of `--llzk-to-smt-no-cf`,
`--llzk-to-smt-no-cf-naive` or `--llzk-to-smt-cf-only` produces. So G10 stops at
"the module is admissible and lowers"; it runs no solver and checks no
constraint. Recorded here because R2-12's finding was that the project described
the toolchain as offering nothing at all against `constrain()` without anyone
having looked. It offers this much, and no more.

## Evidence

Store concise evidence under `doc/llzk/evidence/SNN/`. Record:

- complete command;
- tool version;
- exit status;
- relevant output or result artifact;
- integration commit being tested.

Evidence that exists only in `/tmp` is not accepted.


## G11 — the harness's own error paths

```bash
bash scripts/llzk/test-scripts.sh
```

Every gate above is enforced by `scripts/llzk/*.sh`, and until S21 nothing
exercised any of their *failure* branches — only the happy path, on every run.
That gap shipped a broken fix: R4 found `check-pins.sh` died on git's own
message in a clone with no `upstream` remote, the repair added the intended
diagnostic, and the repair itself was wrong. `check-pins.sh` never sourced
`lib.sh`, so the branch died with `llzk_fail: command not found` and exit 127.
It failed closed, so no gate noticed, and it survived R4's verification and R5's
bootstrap.

G11 runs *first* in `e2e.sh`, though it is numbered last: a broken check would
silently weaken everything below it.

Each case asserts an exit status **and** a message substring. Status alone would
have passed the defect that motivated the gate — exit 127 is non-zero. Two of
the cases are the negative direction of
`require_llzk_opt_discriminates` and `require_llzk_witgen_discriminates`, whose
positive direction ran on the real tools every time while the direction that
matters ran never.

There are now 177 cases. The witness controls reject a permissive shim, a stub
execution backend, a checker permissive for public output, and three
content-aware partial checkers: public `out0` only, full-witness `w0` plus all
outputs, and full-witness all cells plus `out0`. Each partial checker is first
shown green on its baseline, red on a checked field, and falsely green on an
ignored canonical mutation. The controls independently exercise each strict
minimum, prove numeric rather than serialized-key ordering with scrambled
double-digit fields, and pin widest-interface selection, empty/malformed/missing
selector inputs, deterministic ties, literal count pins, and both directions of
exact-count enforcement. Xor32 adds exhaustive four-output full/public attacks,
exact old-raw full/public alternates, PID-derived non-raw alternate paths, and every
validation failure of the raw-reference and exhaustive-output helpers.
BLAKE3.G adds an exact-layout exhaustive-interface helper with a content-aware
452-call log covering four green baselines and all 448 isolated red mutations;
it rejects wrong arity, missing, extra, malformed, and drifted interface
carriers, plus nonnumeric counts and noncanonical scalars, and demonstrates that
a checker ignoring `w42` is caught. Each
partial or path-specializing shim has its own green, checked-field red, ignored
field/alternate false-green, and whole-helper red demonstration. The complete
e2e driver is digest-pinned, with an inserted early-`continue` and a valid-shell
outside conditional independently proving unreachable Xor32 or BLAKE3.G calls
turn G11 red. Seven S29 overlay controls
independently reject a missing overlay, unrelated overlay, indirect overlay,
an extra overlay path, wrong status on the expected path, and committed or
uncommitted post-overlay Xor32 drift. Ten enforce
the public CI policy in
`check-actions-pinned.sh`: mutable action tags, moving hosted-runner or Rust
inputs, writable default tokens, and implicitly enabled hosted or self-hosted
benchmark entry points go red. An LLZK job without the exact trusted public
substituter and source-build refusal also goes red. Full-SHA/local actions,
release-pinned inputs, and explicitly opt-in self-hosted jobs go green. The
repository's real workflows are checked as the final positive control.

It needs no LLZK tools and no Lean build: `lib.sh`'s helpers are called
directly and `check-pins.sh` is driven against throwaway `--shared` clones, so
it completes in roughly twenty seconds on the audit host. The clones get the
*working tree's* scripts copied in,
so an uncommitted regression is caught.
