# R7 — adversarial review of the finished Stage 1, the closed gaps, and the plan

**Date:** 2026-08-09
**Tree reviewed:** `acbf8c32` on `clean-to-llzk/integration`, working tree clean
**Tools:** the pinned `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0`
**Method:** five independent reviewers, each told to falsify a different surface —
the GAPS register against the code, the coverage measurement, the S25–S27 session
packets against the actual upstream diff, the gates against the binaries, and the
theorem statements against their prose. The gates were reproduced on the reviewed
commit before anything else ran, and every load-bearing finding below was
re-verified against the primary source (the upstream file, the binary, the
elaborator) before being accepted. Evidence under `evidence/R7/`.

## What held

Stage 1 reproduces, again. `bash scripts/llzk/e2e.sh` printed
`PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12` on `acbf8c32` before any
change: 12 circuits, 33 vectors, both witgen backends. CI on
`alexanderlhicks/clean` PR #1 is green on both runs (2026-08-02, 4h27m; and
2026-08-04, 3h12m — note the first ran at 74% of GitHub's 6-hour job limit).
Upstream Clean is still `0e53b9f2` — S25's target has not moved — and upstream
LLZK is 9 commits past the pin, none relevant.

Attacked specifically and did not move:

- **The soundness chain is real.** `spec_of_compile`'s four links were checked
  one by one against Clean core; `FullGuarantees` really is discharged by
  `hnoint` because `Analyze` refuses `.interact` by name; the offsets match
  `Source.ofFormalCircuit` exactly; no ∃-where-∀ anywhere in the key theorems.
- **Axiom hygiene is exactly as documented.** `#print axioms` on the six generic
  theorems (`spec_of_compile`, `ofSource_lookups_iff`, `canonical_of_recognize`,
  `certified_membership`, `registryOk_of_recognize`, `size_eq_of_recognize`)
  gives `[propext, Classical.choice, Quot.sound]` only. The babybear
  instantiations add precisely the two `native_decide` prime facts GAPS §8
  admits. No `sorryAx` anywhere in the closure — in particular
  `Clean/Circomlib/Poseidon.lean`'s `sorry` (see R7-16) is outside it.
- **The instantiation is non-vacuous.** `ofModule` on the compiled
  `Addition8FullCarry` module returns `some` with 4 equality polynomials,
  1 lookup, 1 global — `heqs` quantifies over real content.
- **The fatBytes/selfTable attack is blocked by `resolve`.** Certifying a
  512-row table against a self-certifying `selfTable` compiles, but `resolve`
  demands `l.table = ct.table.toRaw`, which fails at 300 — no false `Spec` is
  derivable through `spec_of_compile`. GAPS §1's "second half open" framing is
  accurate.
- **§4's closure (A1) is exact.** Every named theorem exists, is proved without
  `sorry` or axioms, the canonicity hypothesis is genuinely discharged from the
  compiler's own checks, and the residual is the one named `#guard`.
- **The R2-06/R4b-2 vacuity class stayed closed.** No-`@constrain` modules are
  rejected; the G9 agreement-count pins kill silent corpus shrinkage; a
  hand-built `Module` entry cannot dodge both G12 and the `none`-count pin;
  every emitted artifact is inside some gate's loop (the copyCell hole is
  closed — `CopyCell` is a corpus entry with 3 vectors).
- **The register describes the code.** GAPS §1/§2/§5/§8's architecture claims
  match the code line for line; §5 (`lower_spec`) is the register at its most
  accurate, including "nothing outside `IR.lean` uses it".

## Findings

Severity: **S** = a written claim is false in a way that would misdirect work or
overstate assurance; **M** = overstated/missing; **m** = drift.

### The plan (these reorder the roadmap)

- **R7-05 (S).** *"The whole bitwise half is blocked by exactly two witness-IR
  constructors" is false, and the measurement's own diagnostic counts prove it.*
  Every byte-oriented bitwise gadget looks up `ByteXorTable` — a **3-column,
  65536-row** table (`Clean/Gadgets/Xor/ByteXorTable.lean:8`, `fieldTriple`) —
  and the backend is single-column-only (D013, enforced at
  `Table.lean` and `Analyze.recognizeLookup`). The reported diagnostic counts
  decompose exactly: Xor32 "lxor (5)" = 1 lxor + 4 unregistered-table lookups;
  Keccak256.Theta "lxor (450)" = 50 lxor + **400 lookup refusals**. 80–89% of
  the diagnostics behind the headline were multi-column-lookup refusals
  summarized as "lxor". Implementing `land`/`lor`/`lxor` + `ite` unlocks
  roughly **5 gadgets**, not Keccak/BLAKE3/Xor/And — those additionally need
  multi-column `constrain.in` and the certification of a 65536×3 table.
  ROADMAP.md itself lists multi-column tables as a *later* Stage-2 item,
  contradicting its own headline. **Consequence: D013 retirement moves onto the
  critical path, directly after the bitwise constructors.**
- **R7-06 (S).** *The coverage measurement is not reproducible.* Commit
  `89a6f4e8` touched two documentation files; no script, `#eval` file, or test
  performs the sweep, and `evidence/` has no entry for it. The numbers are
  consistent with a real run (R7-05's decomposition), but nobody can re-run it.
- **R7-07 (M).** *The measured universe is 13 hand-picked gadgets of ~128
  top-level circuits.* `Compilable` has exactly one instance —
  `FormalCircuit` — so `GeneralFormalCircuit` (19), `FormalAssertion` (8),
  `FormalTable` (3), `InductiveTable` (6) and `LookupCircuit` (1) are not
  "refused with a diagnostic": they are outside the entry point's type, which
  the coverage section never states. `Clean/Circomlib/` (~35), `Clean/Tables/`
  (8), `Clean/Examples/` (14) and `Clean/Air/` (4) were not measured at all.
  The SHA256 row is also wrong: `SHA256Round` is blocked by `let`-steps,
  `mapRange` outputs and `>>>` in its witnesses (`SHA256/Add32.lean:46-52`),
  not only by field width; "not a frontend limitation at all" is false.
  And "the arithmetic half compiles" is circular — arithmetic-only gadgets that
  do **not** compile include `IsZero`/`IsEqual` (need `ite` **and** `inv`).
  Honest summary: measured-compiling today ≈ 7/128; plausibly-compiling ≈
  25–30/128; bitwise+ite adds ~5; bitwise+ite+multi-column tables adds the
  ~29-gadget Keccak/BLAKE3/Xor/And family; SHA256 needs `mapRange`/`letF`/shr
  on top; ~60% of the library needs witness-IR loops, `inv`, channel
  interactions, or a `Compilable` instance that does not exist.

### The next sessions (these were about to be executed on false premises)

- **R7-08 (S).** *S25's "translate exactly, re-prove `eval_ofWitgen`, gates
  unchanged" is unsatisfiable.* Upstream `U64Expr.val` **truncates**:
  `UInt64.ofNat (FiniteField.val …)` — "`ZMod.val` truncated to 64 bits"
  (upstream `Clean/Circuit/WitnessIR.lean:82,173`), where the deleted
  `NExpr.val` was exact. For the recognized `div` shape the two semantics
  differ whenever `val x ≥ 2^64` — reachable exactly on bn254 and grumpkin,
  both in the registry. `eval_ofWitgen` as stated (generic `[FiniteField F]`)
  becomes **false** under the packet's prescribed translation; `mod` survives
  only because 256 ∣ 2^64. The corpus won't notice (all div/mod entries are
  babybear), so the failure mode is green gates over a silently weakened
  meaning theorem. S25 must record a decision: restate with
  `FiniteField.size F ≤ 2^64` (excluding bn254/grumpkin div/mod witnesses from
  the meaning theorem, said out loud), or change the emitted reading — either
  is a decision entry, not a mechanical port. D025 frames the width problem as
  small-fields-only; the truncation hazard is on the *large*-field end too.
- **R7-09 (S).** *S27's premises are false.* `~/zkgolf/submission_gf2` is over
  **GF(2)** (`F2Bits.lean:17: p2 := 2`), not bn254 — `circomPrime` belongs to
  the SHA256 challenge. GF(2) is not in `FieldSpec.registry`, so the ported
  gadgets cannot become corpus entries as planned. The submission contains
  **zero bitwise operations** (over GF(2), xor is `+` and and is `*`; grep
  confirms no `^^^`/`land`/`lxor` and no `Witgen` usage), so the claimed S26
  dependency does not exist. Its real blocker is elsewhere: the Add32 carry
  recurrence needs `Step.letF` chains, which S26 *excludes* — a `lit` inlining
  doubles per bit. The tops are also `GeneralFormalCircuit` (no `Compilable`
  instance), and the `computableWitnesses` proofs must be rebuilt across 203
  upstream commits. As written, S27 delivers nothing exportable even after S26.
- **R7-10 (M).** *S25's constructor inventory has three errors.* Upstream
  `FExpr` gains no `lor`; `BExpr` is not new (only `flt` and `bit` are);
  `mapRange` existed at the pin (only `envRange` and `bitsOf` are new). The
  exhaustive matches in `Witness.lean` must be written from the upstream file,
  not from the packet. The packets also miss the `circuit_norm` re-keying
  (upstream removed `@[circuit_norm]` from `ProvableStruct.eval`/`toComponents`,
  added simprocs and new `@[simp]` `fromNat` lemmas), which lands on
  `Test/Soundness.lean` and `Test/Lookups.lean` with no witness-IR involvement.
  Verified in the packets' favor: the **constraint-side API has zero diff**
  (`Operations.lean`, `Subcircuit.lean`, `WitnessGeneration.lean` untouched;
  `Formal.lean`/`Theorems.lean` proof-internal only), so breakage really is
  concentrated in `Witness*`/`WitnessCheck*` + tests.

### The gates

- **R7-01 (S).** *G0 is blind to the working tree it certifies.*
  `check-pins.sh` runs `git diff --name-only <base> HEAD`, comparing two
  commits — while G1/G2 build and emit from the **working tree**. Demonstrated:
  an uncommitted edit to `Clean/Utils/Primes.lean` reports "byte-identical
  PASS" while being what gets built. G9 does not catch it (both sides move
  together). Fix: fail G0 on a dirty Clean-core working tree.
- **R7-02 (M).** *Constraint content has exactly one line of defense, and the
  toolchain gates certify nothing about it.* Demonstrated with the binaries:
  a module whose `@constrain` demands `out0 == 8` while `@compute` writes 7
  (unsatisfiable), one with a deleted multiplication constraint, one with an
  **empty** `@constrain` body, and an `Addition8FullCarry` with one of four
  `constrain.eq`s dropped — each passes G3, G4, G5, G6, G10a **and lowers to
  SMT under G10b** without complaint. The only defense is G9's Lean-side
  `agree` at emit time, and the discriminator's LLZK probe checks only that
  `@constrain` *exists* (LLZK rejects a missing `@constrain` function but
  accepts an empty one). Same shape for fields (the R4b-1 pattern at file
  level): renaming every `felt.type` to `"bn254"` in a babybear module passes
  G3/G4/G5 — `Analyze.checkField` is the sole guard. This is documented ("G9
  is a precondition of emission"; D017) and the on-disk artifacts are
  hash-pinned goldens, so it is assurance *concentration*, not a hole — but it
  is the strongest argument yet for GAPS §2/A5: a Lean parser from the rendered
  text back to `Module` with a round-trip theorem would give the artifact a
  second, independent line of defense. Recorded in GAPS.
- **R7-04 (m).** Three reachable refusal paths have no G8 fixture: the
  `env.size = 0` branch of the undefined-variable refusal (`IR.lean:443`);
  `lowerRecognized`'s own field-registry throw (`Circuit.lean:177`); and
  `checkLowerable`'s const≥prime in the witness-cell and lookup-entry
  positions (only output and assertion positions are pinned).

### The theorems and the register

- **R7-12 (M).** *`spec_of_compile`'s lookup hypothesis is not "every lookup
  the reader extracts", and both GAPS §3 and the docstring say it is.*
  `hlookups` is stated over the **source's** lookups in certificate-side form
  (membership in `ct.exported.values` for the `ct` whose *Clean table*
  matches); it never mentions `C.lookups`/`C.globals`, and no theorem bridges
  module-side satisfaction to it. The bridge needs `exported.name =
  table.name` — which `CertifiedTable` does **not** demand (`Certifies`
  constrains values only; the mismatched-name construction elaborates,
  `evidence/R7/probes.txt` P4). A config pairing exported "Bytes" with a Clean
  table named "Foo" and vice versa compiles, and then module satisfaction and
  `hlookups` are incomparable. The theorem is true; the prose overstates it —
  this project's named failure mode. For the shipped corpus the names
  coincide, so `add8_spec_of_compile` is unaffected in substance. Fix: demand
  the name tie in `CertifiedTable` (one field, `rfl` at the byteTable
  certificate), and correct the prose.
- **R7-13 (M).** `Constraints.lean:377` — "there is no way to obtain a module
  from this backend that has not been compared against its Clean source" — is
  false as written: `compileSource`, `compileSource'` and `lowerRecognized`
  are public and return un- or half-compared modules, and the corpus's six
  `Square_*` entries use one of them. G12 confines all three; the blanket
  sentence stands anyway, and the same file says at `:464` that the public
  entry points are *not* here. D022's "nothing public accepts a plain Config"
  has the same shape.
- **R7-14 (M).** ROADMAP.md still lists "no chain from the emitted constraints
  to a gadget's `Spec`" as open — closed by A2, and ROADMAP's own preamble
  says a disagreement with GAPS.md is a defect in this file. CURRENT.md
  contradicts itself the same way: its "What is still not established" list
  keeps §3 and §6 while three other sections of the same file record them
  closed.
- **R7-15 (m).** Numeric drift: "seven public entry points taking
  `CertifiedConfig`" is five defs (+2 theorems); the `@compute` evidence is
  cited as 30, 33 and 27 vectors in different places (33 is current: 27
  circuit + 6 registry); `Test/Soundness.lean` says three hypotheses are
  `#guard`ed, two are (`hm` is entailed, not guarded); GAPS §6 claims a
  2×2×2 red-pin matrix of which 4 of 8 cells exist.
- **R7-16 (m).** CURRENT.md's "nothing in the tree carries a `sorry`" is false
  as written: `Clean/Circomlib/Poseidon.lean:22` has one (in pinned core,
  outside the backend's closure — confirmed by the axiom probe). GAPS §2 says
  "`Print.lean` proves … equal modules render to equal strings"; `Print.lean`
  contains zero theorems. The `WitnessSet` reader does not check `global.def`
  types (moot in `@compute`, which cannot reference globals; the constraint
  reader covers them) — "both readers check every `global.def`" is literally
  true of one.

## Verdict

Stage 1 stands: the pipeline milestone — a Clean circuit compiled to LLZK,
accepted, round-tripped, both witgen backends agreeing with Clean's own
interpreter, the emitted constraints proved to imply the gadget's `Spec` — is
reproduced, and its formal chain survived direct attack. What did not survive
is the **plan**: the coverage headline ordering Stage 2, and two of the three
bootstrapped session packets, are built on premises the primary sources refute
(R7-05, R7-08, R7-09). The repair is mostly to documents, two scripts, one
structure field, and the packets — plus making the coverage sweep a checked
artifact so the next headline cannot drift.
