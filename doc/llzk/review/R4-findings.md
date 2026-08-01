# R4 — two independent adversarial reviews, and what they broke

R3 closed by saying it was not independent: it was written by the session that
wrote the repair. R4 fixes that. Two reviewers with no prior context on the work
were run against the tree and told to falsify claims rather than confirm them —
one over the proof track (`Poly`, `Constraints`, `TableCert`, `Field`,
`Test/Constraints`), one over the emitter and harness.

Both worked from the repository alone, wrote scratch Lean and shell to construct
counterexamples, and modified nothing.

**Verdict: nine findings, five of them breaking a claim the project made in
writing. All fixed; every counterexample re-run against the fix.** Two of the
five were *severe*, and both were claims this session had made about its own
work in the preceding hours.

## The two that matter most

**R4a-1 — D019 was not enforced at all.** The claim was that every recognizer
and entry point requires `CanonicalRepr`, so a field whose `val` is not the ring
representative is a type error. It was false, for a reason that is invisible
without checking: in Lean 4 a `variable [C F]` binder is included in a
declaration only if the *instance itself is used* there, and `CanonicalRepr`'s
two fields are never mentioned outside `Field.lean`. All six `variable` lines
were silently dropped and the two `omit … in` lines were no-ops. The reviewer
scanned every constant whose type mentions the class and found exactly one: the
instance. Then it built `F 5` with a `val` swapping 2 and 3 — satisfying every
`FiniteField` law, provably not `CanonicalRepr` — and compiled a circuit saying
`x + 3` into a module saying `x + 2`, with both halves of G9 green.

Fixed by putting `[CanonicalRepr F]` in the *signatures* of `recognize`,
`compileSource`, `compileSource'`, `compileSourceVerified`, `agreeCompiled`,
`compile`, `emit`, `emitSource`, `witness` and `Entry.ofSource`, and verifying
with `#check` that it survives elaboration. It does.

The reviewer's deeper point stands and is now recorded in D017: the constant
encoding is a *shared* convention of the two readers — the emitter writes
`FiniteField.val c`, `ofModule` reads `FiniteField.fromNat`, and
`fromNat_val` makes the round trip exact — so it is the one thing G9 structurally
cannot cross-check. `CanonicalRepr` is what pins it, which is why the class had
to be genuinely required rather than nominally present.

**R4b-1 / R4a-7 — `Config.field` was never checked against the registry.**
`FieldSpec` is a public structure, so `Config.field` could be any `(name, prime)`
pair, and `checkField` compared only the prime — both sides supplied by the
caller. `{ name := "bn254", prime := 2013265921 }` emitted a babybear circuit
typed as `bn254`, with the babybear `-1` coefficient, and was accepted by
`llzk-opt`, both witgen backends, both halves of G9 and G10. This is exactly the
failure mode D010 says it exists to prevent, and it was invisible to every gate.

Fixed: `checkField` requires `cfg.field ∈ FieldSpec.registry`. That also removes
the only caller-supplied string that reached the renderer, which is why `Print`
needs no escaping — every other name it emits is generated.

## The rest

| # | Finding | Fix |
|---|---|---|
| R4b-2 | `llzk-opt` had no discriminate self-test — only `--version`, the same "existence check" `lib.sh` rejects as insufficient for `llzk-witgen`. A four-line shim answering `--version` and exiting 0 made G3, G4 and G10 vacuous while `e2e.sh` printed PASS. | `require_llzk_opt_discriminates`: must verify a real artifact and must reject a non-MLIR file. The shim now aborts the run. |
| R4b-3 | D005's first bullet was false. `Param.value` is a public projection, so a body can capture a `Value` from a *different* component and reference an index its own function never allocated; `llzk-opt` said "use of undeclared SSA value name". | `Builder.assemble` checks every operand against the function's own allocation and refuses otherwise. `component` returns `Option StructDef`; the bullet now says what is actually true. |
| R4a-3 / R4b-4 | D018's "no module leaves this backend without the check" was false: `lower` was public and ran no validation, and the six `Square_*` corpus entries go through it. | `lower` is private; `lowerRecognized` is the validated door for `Recognized` built by hand, and runs the field-registry and table checks. D018 now says "no module obtained through `compile`/`emit`", which is what the theorem supports. |
| R4a-4 | G9 was blind to input arity on both halves: neither `ofSource` read `Source.inputSize`, and the module-side count was only an offset. A module built for 1 input matched a 4-input source. Exactly the D014 blind spot the docstring claimed to avoid. | `ConstraintSet` and `WitnessSet` carry `inputs`, and `agree` compares it. |
| R4a-5 | `ConstraintSet.ofModule` accepted `struct.readm %self[@w0]` in a component whose only member is `@junk` — `memberVar` searched generated names and never consulted `m.root.members`. Same class as R3-02, fixed for globals and left for members. | `memberVar` takes the declared member names and requires membership. |
| R4a-2 | `CertifiedTable`/`Config.ofCertified` is **vacuous as a guarantee**: the caller picks both the export table and the Clean table, so `selfTable e` with `Contains _ x := val x ∈ e.values` certifies any rows. The reviewer compiled `Addition8FullCarry` with a `@Bytes` global holding one row. | Claim withdrawn, not patched: the mechanism carries the obligation, it does not enforce it. Closing it needs the `Table` to survive into `Lookup`, which is a change to Clean's core. D012 says so. |
| R4a-6 | `ofSource_eqs_iff` covers only the *assertion* half of `ConstraintsHoldFlat`; the docstring said the whole thing. The lookup half has no semantic theorem, and the bridge that would give it one (`certified_membership`) is instantiated nowhere. The module docstring also cited `ofSource_holds_iff`, which does not exist. | Docstrings corrected to say exactly which half is proved and why the other has none. |
| R4b-5 | The G10b tolerance list grepped the whole stderr log, so a tolerated pattern excused any other error beside it — and the comment claiming no corpus module reaches the `global.read` path was wrong, since Addition8FullCarry's log carries those as *warnings* alongside the tolerated error. There was also no floor on `smt_ok`, so a change making every module carry a `felt.umod` would print PASS with 0 lowered. | Every `error:` line must be tolerated or the gate is red; `LLZK_EXPECTED_SMT_OK` is a floor. |
| R4b-6 | `variables 0 to {env.size - 1}` printed "0 to 0" when nothing is in scope — `Nat` subtraction. The message asserted that variable 0 is in scope in the sentence saying it is not. | Separate message for the empty case. |
| R4b-7 | `EmitMain`'s G9 line counted `constraintsAgree` and claimed both halves. | Counts both, and says what the other six entries are. |
| R4a-8, R4b-8 | `LLZK.fromNat_val` duplicated `FiniteField.fromNat_val`; `doctor.sh` executed `check-pins.sh` directly while `e2e.sh` used `bash`; `check-pins.sh` died on git's own message in a clone with no `upstream` remote. | All three fixed. |

## What survived

Worth recording, because a review that finds nothing sound is not a review.

- **Every `Poly` operation carries its evaluation theorem**, and the canonicity
  the normal form provides survived stress-testing well beyond what this project
  had done: 400 pseudorandom depth-4 expressions all normalising to sorted,
  duplicate-free, zero-free lists; 200 random triples confirming commutativity,
  associativity, distributivity and cancellation produce *identical*
  representations; and an exhaustive check over all 56 sorted monomials of degree
  ≤ 3 in 5 variables that `Monomial.before` is a strict total order and
  `Monomial.mul` is commutative and associative.
- **`ofStatic_certifies` and `byteTable_certifies` are sound and non-vacuous.**
  The reviewer tried to make `Certifies` vacuous through its `∀ (t : Array F)`
  quantifier and could not. The weakness is entirely downstream — R4a-2.
- **`ofSource_eqs_iff` is correct in both directions**, uses no unsatisfiable
  hypothesis, and the orientation of `Poly.sub (var (.output j)) (toPoly e)`
  matches `constrainBody` exactly; flipping it would go red.
- **R2-03's offset threading is right**, tested three ways: after a rejected
  block, not too large, and — the one that matters for false positives — not too
  small, so a legitimate cross-block read is still accepted.
- **The table registry checks are jointly sufficient** for the `emit` path, and
  `isSymbolName` is ASCII-only so a Unicode name is refused rather than mangled.
  Nine MLIR/LLZK keywords tested as global names; `llzk-opt` accepts all.
- **Rejection-path fixture coverage is complete**: every `.error` construction
  site matched to a `#guard_msgs` fixture, except the three genuinely
  unreachable ones.

## Residual risks the reviewers named, and what became of them

The reviewers listed four risks inside G9. Two were real and are now closed; two
are covered by a different gate, which the list did not say. Checked rather than
asserted — `Test/Constraints.lean` pins the first two.

| Risk | Verdict |
|---|---|
| Nothing links the member `@compute` writes to the one `@constrain` reads | **Covered.** A constraint reading `@w1` where the circuit names cell 0 gives a polynomial over a different cell, so the comparison goes red. Pinned by the `crossedWires` control. A cell that appears in *no* constraint would slip past G9, and is caught by G5–G7, which compare `w{k}` by name. |
| The emitted lookup table's *contents* are never compared | **Was real; closed.** `ConstraintSet` now carries the module's globals and compares them against the rows the registry declares. Before this, compiling `Addition8FullCarry` with a one-row `@Bytes` instead of 256 passed G9. Pinned by the `oneRowBytes` control. |
| "Witness cell `k` ↔ circuit variable `inputSize + k`" is a tautology inside the check, so G9 cannot see an error in `Analyze`'s offset bookkeeping | **Covered elsewhere, and stated.** The offset logic is covered by fixtures (`selfReadingBlock`) and by R4's own three threading probes, and differentially by G5–G7. G9 is not the gate for it. |
| Constant encoding is a convention *shared* by both readers | **Irreducible in this design, and pinned by a class.** The emitter writes `val`, the reader reads `fromNat`, and `fromNat_val` makes the round trip exact — so no two-reader comparison can cross-check it. `CanonicalRepr` (D019) is what fixes the convention, which is why R4a-1 mattered so much: the class had to be genuinely required, not nominally present. |
| `ofModule` does not check the `Ty` operands | **Covered by G3.** `llzk-opt` type-checks every operand; a module that got there would not verify. |

## What is genuinely left

One boundary and one improvement, and they are different kinds of thing.

**D017 — the reading of LLZK — cannot be closed here.** `llzk-witgen`'s own help
text says it: *"llzk-witgen v1 ignores constrain() and traps on bool.assert."*
There is no executor for `@constrain` in the pinned toolchain and no formal LLZK
semantics in Lean, so the `@constrain` half of the reading has no empirical
check and cannot acquire one from this repository. Closing it means formalising
LLZK, which is VeIR's project (D003). The `@compute` half does have evidence: 30
vectors across two independent LLZK backends.

**S20 — the preservation theorem — is an improvement, not a gap in the
artifacts.** It is worth being precise about what it would buy, because the
residual list read as though emitted modules were at risk. They are not: every
module `compile` returns has been compared against its circuit on both sides, so
a lowering bug produces a *refusal*, never a wrong module. S20 would make the
refusal impossible rather than merely never-observed. That is robustness and
diagnosis quality, not soundness of output.
