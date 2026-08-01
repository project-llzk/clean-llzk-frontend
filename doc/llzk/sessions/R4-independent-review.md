# R4 — two independent adversarial reviews, and their repairs

Status: complete
Depends on: S19 (`sessions/S19-witness-side.md`)
Worktree: `/home/alh/LLZK/clean-llzk-frontend`
Branch: `clean-to-llzk/integration`

## Objective

R3 closed by saying it was not independent. Get eyes on this work that are not
the session that wrote it, and act on what they find.

## Method

Two reviewers, no prior context, read-only, told to falsify rather than confirm
and to construct counterexamples rather than read. One over the proof track, one
over the emitter and harness. Both were given the specific written claims to
attack, the tool paths, and a scratch directory.

Both flagged that the tree changed under them mid-review — S19 landed while they
were working — and both re-verified every finding against the final state and
recorded the hashes. That is a real cost of running reviews concurrently with
work, and next time the tree should be frozen first.

## Findings and repairs

Nine findings, five breaking a written claim, two severe. The table is in
`review/R4-findings.md`; the two that matter:

- **D019 was not enforced.** `variable [CanonicalRepr F]` is dropped unless the
  instance is used, so the class this session had just added and documented as
  required was present in zero signatures. A field with a non-representative
  `val` compiled to a wrong module with both halves of G9 green.
- **`Config.field` was never checked against the registry.** A babybear circuit
  emitted as `!felt.type<"bn254">`, accepted by every gate. Exactly D010's
  failure mode.

Also fixed: `llzk-opt` had no discriminate self-test (a `--version`-only shim
made G3, G4 and G10 vacuous); D005's SSA-scope bullet was false; `lower` was a
public unvalidated path used by six corpus entries; G9 was blind to input arity;
`ofModule` accepted reads of undeclared members; the G10b tolerance list grepped
the whole log and had no floor; a `Nat`-subtraction off-by-one in a diagnostic;
`EmitMain` counted one half of G9 and claimed both; and three small duplications
and shell nits.

Two claims were **withdrawn rather than patched**, because the mechanism cannot
support them: `CertifiedTable` carries D012's obligation but cannot enforce it,
and `ofSource_eqs_iff` covers the assertion half of `ConstraintsHoldFlat` and not
the lookup half.

## Acceptance gates

```bash
export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen
bash scripts/llzk/e2e.sh
```

`PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10`, exit 0.

## Evidence

- `doc/llzk/evidence/R4/counterexamples.txt` — every reviewer counterexample
  re-run against the fix.
- `doc/llzk/evidence/R4/gates.txt` — the full run afterwards.

## Handoff

- Changes: `Analyze` (field registry), `Expression` (empty-scope message),
  `IR` (operand check, `component : Option StructDef`), `Circuit` (`lower`
  private, `lowerRecognized`), `Constraints` (input arity, declared members,
  docstrings, duplicate lemma), `WitnessCheck` (input arity, explicit binders),
  `TableCert` (claim withdrawn), `Corpus`, `EmitMain`, `RendererFixture`,
  `scripts/llzk/{e2e,lib,doctor,check-pins}.sh`, and the decision log.
- D005, D012, D017, D018, D019 amended; all five had said more than was true.
- Resulting commit: recorded by `git log` on this branch.
- Exact next action: **S20**, the preservation theorem. R4's residual-risk list
  is the argument for it: three of the four items disappear if the cross-check
  becomes unnecessary rather than broader.
