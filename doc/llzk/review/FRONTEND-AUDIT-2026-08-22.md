# Clean-to-LLZK frontend audit — 2026-08-22

## Verdict

The frontend is a credible late-stage release candidate for its deliberately
scoped feature set. Its active correctness story is materially stronger after
this audit, and the complete post-repair matrix passes on both the accepted LLZK
pin and LLZK upstream main.

This is **not R8 and not a publication recommendation**. The planned release
sequence remains:

```text
XOR range contract -> headline example promotion -> frozen-candidate R8 -> publication decision
```

No new critical or high-severity finding remains open from this audit. The
known table-identity and LLZK-semantics boundaries remain open and are not
reclassified as bugs fixed here.

## Reviewed state

- Frontend branch: `clean-to-llzk/s28-multicolumn-tables`
- Review starting commit: `13729783d9b7df162fcde86caa17ab0294f078ce`
- Clean base and upstream head: `0e53b9f2d05f06defa2aa0a859f549b611583f10`
- Lean toolchain: `leanprover/lean4:v4.32.2`
- Accepted LLZK pin: `25fb3740ea3465c9129a06289297bb4f0554b7a5`
- LLZK upstream main checked: `b5c110d1088e93d6786f66ec1e155be87bae755f`
- Frontend inventory: 31 Lean files / 8,603 lines under
  `Clean/Backend/LLZK`, plus nine LLZK harness scripts and the public documents

`git ls-remote` confirmed that Clean upstream still points at the pinned base.
LLZK main is one commit ahead of the accepted pin. Its delta is a walk-helper
refactor (13 files, +107/-99), including replacement of a manual witgen walk by
`walkCollect` with the same exclusion of `@constrain`; it does not require a
frontend change. Compatibility was established by execution, not inferred from
the diff.

## Scope and method

The review covered:

1. the accepted source subset and fail-closed diagnostics;
2. field selection and canonical-representation assumptions;
3. expression, witness, U64, bitwise, shift, and `bitsOf` lowering;
4. typed IR construction and rendered LLZK syntax;
5. constraint and witness translation validation (both halves of G9);
6. lookup export, multi-column row preservation, and certificates;
7. the generic module-to-gadget soundness chain and concrete Add8/And8 uses;
8. corpus generation, both witness backends, public output, LLZK analysis, CI
   policy, pin checks, confinement, and harness discriminators;
9. theorem axiom closure, dead declarations, compatibility wrappers, stale
   comments, public counts, and roadmap/readiness claims.

The audit used source inspection, call-site searches, mutation controls, Lean
builds and theorem probes, the accepted LLZK binaries, and a separately built
LLZK-main toolchain. A green gate was treated as evidence only where a red
control or a mutation established that it could discriminate.

## Findings and resolutions

### A-01 — A5 ignored constraint arithmetic and the public member interface

**Severity before repair: high. Status: fixed and regression-tested.**

The old `RenderCheck` protected globals, `struct.readm`, `array.new`,
`constrain.eq`, and `constrain.in`, but ignored `felt.const`, `felt.add`/`mul`,
`global.read`, member declarations, and constraint parameters. Those ignored
forms determine the meaning and public interface of the rendered module.

Two concrete mutations demonstrated the false green:

- in `Multiply`, change the constraint-side `felt.mul` to `felt.add`;
- change `struct.member @w0 ... {signal}` to `{llzk.pub}`.

Before the repair, both mutations were accepted by `RenderCheck`, parsed and
round-tripped by `llzk-opt`, and passed both full-witness backends. The
visibility mutation changed `--output-scope=public` by adding `w0`, proving an
observable contract change rather than a merely theoretical omission.

The repair makes `RenderCheck` read:

- all globals and their nested row-major type/value data;
- every member name, type, order, and visibility;
- every `@constrain` parameter;
- every current `Stmt` constructor in `@constrain`.

Unknown constraint-body statements now fail closed. The new
`Module.render_semanticSurface` theorem states the checked result, while the old
theorem name remains as a compatibility alias. Mutation guards cover changed
arithmetic, constants, global reads, member visibility, parameters, member
aliasing, deleted constraints, row shape, field type, and function boundary.

### A-02 — typed G9 readers did not require the exact member layout

**Severity before repair: medium. Status: fixed and regression-tested.**

The constraint reader counted signal/public members and checked field types;
the witness reader derived counts from writes. Neither required the exact
ordered `w0...` signal / `out0...` public declaration. That was safe for the
current private component builder, but weaker than the readers' claims and
unsafe for a hand-built or future typed module passed to `verify`.

`memberLayout` is now the shared independent predicate. Both readers require
exact count, name, order, type, and visibility. Direct controls reject changed
visibility, name, and order.

### A-03 — public output was documented but never exercised by the corpus gate

**Severity before repair: medium. Status: fixed.**

G5-G7 used only `--output-scope=full-witness`. LLZK's full-witness JSON places
both internal and public members under `signals`, so it cannot distinguish a
visibility error.

The emitter now writes one `.public.json` expectation per vector. Both the
interpreter and execution-engine backends check both full-witness and public
scopes for all 51 vectors. This independently executes the stable `out{j}`
interface and made the A-01 visibility control explicit. The harness self-test
also perturbs each scope for each backend, and G11 includes a shim that is honest
on full-witness checks but permissive on public output; the discriminator must
reject it.

### A-04 — unused proof vocabulary and obsolete theorem wrappers

**Severity: low maintenance/assurance debt. Status: removed.**

The approximately 390-line `ExprAlgebra` / `Assign` / `readStmts` /
`FieldExpr.lower_spec` block had no consumer outside its own file. Prior review
already proved that grossly wrong lowerings satisfied it and that it did not
compose into the active module readers. Keeping it made the repository look
more verified than it is and imposed a second statement vocabulary to maintain.

The block was removed. The repository now states the honest boundary directly:
it validates every supported translation, but it does not verify the translator.
A future proof must cover whole functions and connect to the active G9 readers.

The compile-specific `eqs_iff_of_compileSource'` and
`lookups_perm_of_compileSource'` wrappers were also unused and removed. The
soundness chain already consumes the more general `eqs_iff_of_agree` and
`lookups_perm_of_agree`. Two small orphaned helpers were removed as well.

### A-05 — documentation drift

**Severity: low, public-readiness relevant. Status: fixed.**

Corrected items include:

- the stale LLZK registry-source revision in `Basic.lean`;
- README corpus counts (`12/33` to `15/51`);
- architecture text that incorrectly limited public outputs to witness aliases;
- A5 descriptions that listed only five protected forms;
- current/roadmap/decision references to the retired partial theorem and
  wrappers;
- the old R2 claim inventory, now clearly labelled historical.

## Correctness claims upheld

| Claim | Justification and validation |
|---|---|
| Unsupported source constructs fail closed | `Analyze.recognizeOperation` and the witness recognizers are exhaustive over the upstream constructors. Rejection goldens build under `CleanTests`; G11 exercises 54 harness failure paths; G12 confines unchecked entry points. |
| The configured field matches Clean and uses canonical representatives | `Analyze.checkField` compares the exact prime; `CanonicalRepr.val_natCast` pins `FiniteField.val` to the prime-field representative. Both G9 readers check every type they interpret. The theorem closure is ordinary Lean axioms only. |
| Supported structural U64 operations do not wrap before LLZK sees them | Recognition computes a conservative exclusive bound; `WExpr.eval_lt_upperBound` proves evaluation stays below it; admitted recursive results are bounded by the field prime. Division/modulo divisors are nonzero and canonical. Two LLZK witness backends agree with Clean on boundary vectors. |
| `bitsOf` means bits of the canonical field representation | `WExpr.eval_bitsOf` proves the bit result from `FiniteField.val`; the implementation does not claim an unstated source integer range. |
| Emitted equalities and lookups are the source system as data | Source and module readers independently produce `ConstraintSet`; `agree` compares counts, globals and permutations. `compileSource'`, then `compile`, refuses disagreement. Red controls drop, duplicate, perturb, split, swap, and regroup constraints/rows. |
| Emitted witness computation is the source witness program | `WitnessSet.ofSource` is an independent traversal with `WExpr.eval_ofWitgen`; `WitnessSet.ofModule` reads `@compute`; verified compilation requires agreement. Copy canonicalisation has step and whole-list preservation theorems. G5-G7 then execute the rendered text on 51 vectors in two backends. |
| Multi-column table rows retain order and boundaries | Globals store nested rows; the reader retains arrays of polynomials; G9 compares ordered rows and multiplicity. Controls reject scalar splitting, column swaps, and regrouping with an unchanged flattened scalar bag. `byteXorTable_certifies` covers the full 65,536-row table. |
| Module constraint satisfaction implies the gadget `Spec`, under named premises | `spec_of_compile` composes module equality satisfaction, module lookup-row satisfaction, certified source lookup semantics, Clean's flat/nested bridges, `can_replace_soundness`, and the gadget soundness field. Add8 and And8 instantiate the residual lookup-resolution premise concretely. |
| Rendered semantic text matches the checked typed module | `Module.render_semanticSurface`, the expanded independent textual parser, red mutation guards, G3/G4 on every artifact, and the two public-output backends cover distinct parts of this boundary. |
| Accepted and current LLZK consume the result | Both toolchains passed G0-G12 after the repair: 15 circuit modules, 51 vectors in two backends and two scopes, two syntax fixtures, all 17 product-program admissions, 10 SMT lowerings, and seven declared skips. |

## Theorem trust audit

The current probe is `evidence/AUDIT-2026-08-22/probe.lean`.

Generic frontend theorems depend only on the standard Lean quotient,
propositional-extensionality, and (where used) classical-choice axioms. No
frontend theorem closure contains `sorryAx`. The concrete Add8 theorem also
contains the two already documented Babybear `native_decide` prime facts; And8
additionally contains its upstream `bv_decide` bit-vector identity. These are
named trusted computation boundaries, not newly introduced assumptions.

The ten `sorry` warnings in the full test build all come from
`Clean/Utils/Test/TestCircuitProofStart.lean`, an inherited Clean test helper.
They are outside the frontend theorem closure and are reported rather than
silenced.

## Reproduced external matrix

Both complete runs ended with:

```text
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
  15 circuit(s), 51 input vector(s), both witgen backends.
  2 renderer fixture(s), syntax only.
  G10a: all 15 + 2 module(s) admitted by --llzk-product-program.
  G10b: 10 module(s) lowered to SMT, 7 out of scope for a declared reason.
```

The 51-vector count is per backend; each vector is now checked in two output
scopes. The six `Square_*` registry fixtures intentionally have no Clean source,
so G9 is reported as not applicable to them rather than passing vacuously.

The accepted pin should remain the reproducible default for this candidate.
Current LLZK main is compatible and only one reviewed commit ahead, but a pin
move is a separate release decision rather than an automatic consequence of a
green compatibility run.

## Boundaries that remain open

1. **Table identity.** A `CertifiedConfig` proves that an exported table
   certifies a chosen `RawTable`, but Clean erases the originating `Table` before
   the compiler receives the lookup. The caller still supplies the association.
   Add8 and And8 discharge it concretely; the generic compiler cannot.
2. **LLZK semantics (D017).** Lean models the intended meanings of `felt.*`,
   `constrain.eq`, and `constrain.in`; LLZK has no formal Lean semantics and the
   available witness tools ignore `@constrain`. A5 proves what text was written,
   not LLZK's mathematical interpretation of it.
3. **Translation validation, not a verified translator.** A lowering defect is
   refused by G9; it is not impossible by construction or theorem.
4. **Completeness is not claimed.** `spec_of_compile` is a soundness implication;
   it does not prove that the emitted system has a satisfying assignment.
5. **Scoped frontend.** Witness loops, `let`/`mapRange`, `ite`, inversion,
   non-`FormalCircuit` sources, dynamic tables, broader field/limb designs, AIR,
   and other roadmap items remain unsupported and must continue to diagnose.
6. **Release blockers remain.** The witness-visible XOR range contract, Xor32
   plus one composed headline example, frozen-candidate R8, organization CI on
   the frozen SHA, and explicit publication authorization are still required.

## Release recommendation

Keep this tree as the basis for the next release increment. Do not publish or
label it frozen yet. Land the XOR range contract and promoted examples on top of
these strengthened gates, then run R8 against one immutable commit. R8 should
re-run the two-toolchain matrix, the theorem probe, the A5 mutations, and the
table-identity premises for every headline example.
