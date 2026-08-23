# Public-readiness milestone

Updated: 2026-08-23

Status: active

Target: a frozen release-candidate commit suitable for an organization-owned
repository under `project-llzk`

Latest completed pre-R8 audit: `review/FRONTEND-AUDIT-2026-08-22.md`; its R8
erratum records the later output-carrier defect. Its repairs pass the full
matrix on both the accepted LLZK pin and exact checked LLZK main `b5c110d1`.
The later Phase-H implementation `a3299ca0` also passes both exact toolchains.
The first frozen R8 candidate `c60d8363` was selected and independently reviewed
on 2026-08-23, then rejected after the review found a module-output theorem gap
and claim/reproduction defects. Repair and a full R8 restart are in progress;
no candidate has passed R8.
Live repair/review evidence is under `evidence/R8-2026-08-23/`.

## Outcome

The repository should be credible to three audiences at once:

- a Clean user should understand what can be compiled and reproduce an example;
- an LLZK contributor should see an impactful frontend rather than a toy
  emitter;
- a formal-methods reviewer should be able to locate the exact theorem, trusted
  boundary, negative tests, and open gaps behind every headline.

Creating the organization repository, pushing branches, or changing repository
settings is a separate publication action. This milestone ends at a reviewed,
green, locally frozen release candidate unless publication is explicitly
authorized.

## Acceptance criteria

### 1. Clean and understandable repository

- The root README identifies this fork immediately, gives one reproduction path,
  and links to current state, roadmap, assurance gaps, and contribution guidance.
- The public reading path is no more than five documents. Historical session,
  evidence, and adversarial-review files remain available but are clearly an
  archive, not onboarding material.
- Active documentation contains no dependency on one developer's filesystem or
  personal fork. Historical evidence may retain exact paths when provenance
  requires them.
- The branch records the accepted upstream Clean revision and every reviewed
  local Clean overlay separately, has a clean worktree, contains no generated
  build products, and publishes every commit selected for the release candidate.
- Licensing and upstream Clean attribution remain intact. **Prepared locally:**
  `PUBLICATION.md` specifies the repository description, topics, branch
  protection, required checks, and security settings; `CONTRIBUTING.md`, the PR
  template, and `SECURITY.md` supply the contribution and vulnerability paths.
  Private reporting must still be enabled during the authorized publication
  action.

### 2. Meaningful, demonstrable progress

- Preserve the Stage-1 vertical slice: `Addition8FullCarry` compiles, the LLZK
  tools accept it, both witness engines agree with Clean, and the typed module's
  constraints imply the gadget's semantic `Spec`, under named hypotheses, for
  the typed output reconstructed from its ordered public `@out{j}` assignment.
- **Done locally:** align to current upstream Clean before adding capability
  (S25, exact fetched head `0e53b9f2`, Lean 4.32.2).
- **Done locally:** review the LLZK toolchain pin after S25 and before
  capability work. L0 ran the previous `5db6f8f9` input and exact then-current-main
  `25fb3740` candidate against one frozen frontend tree. Both passed the
  unchanged complete matrix; D032 advances the accepted pin because the
  candidate's witness, memory, lowering, and build fixes justify the move. The
  immutable SHA, not the unchanged 3.0.0 banner, identifies the accepted input.
- **Done locally:** retire the capability blockers identified and refined by
  R7/S26: bounded structural `U64Expr` plus direct `bitsOf` (S26), multi-column
  lookup tables and their certificates (S28), and the source-visible Xor32
  range contract plus proved generic modulo/XOR/OR bounds (S29 Phase B at
  `7a0f209c`). Conditionals remain a separate control-flow increment.
- Promote at least `Xor32` and one composed bitwise gadget (`BLAKE3.G` or
  `Keccak256.Theta`) from the checked coverage sweep into the end-to-end corpus.
  Each promoted example must reach `llzk-opt`, both witness backends, the Clean
  differential, and the source-to-module checks; a compile-only `#guard` is not
  release evidence. **Xor32 is done locally on `06b80f2f`** with independent
  fixed references, a concrete theorem instance, and the full accepted-tool
  matrix. **BLAKE3.G is done locally on `a3299ca0`** for exact `G 0 1 2 3`,
  with six official-reference-derived rows, a conditional theorem instance,
  and the complete matrix on both accepted LLZK and checked LLZK main.
- **Done locally:** publish a small checked example table generated from, or
  pinned by, repository tests. `EXAMPLES.md` is generated from
  `LLZK.Corpus.corpus`; G1 requires byte equality and `Test/Showcase.lean` pins
  its denominator and labels. Do not use hand-maintained coverage counts as
  evidence.

### 3. High assurance with honest boundaries

- Keep G0-G12 green and falsifiable; all negative fixtures and agreement-count
  pins remain green.
- Keep the A5 renderer check on the release path: rendered globals, members,
  constraint parameters, and every `@constrain` statement are parsed back into
  the typed representation and must round-trip before text is returned. Keep
  both backends' separate public-output checks as the visibility control.
- Keep A7's copy-canonicalisation invariant in the theorem audit; the
  representative map is built by `CopyCanon.run`, whose whole-list invariant is
  proved by `run_preserves` from the single-step theorem.
- Add example-specific instantiations of the generic soundness chain for the
  public headline examples, including multi-column lookup hypotheses rather
  than leaving them implicit in prose.
- Re-run the documented axiom audit. No `sorryAx` may enter the frontend's
  theorem closure; any deliberate native-decide dependency remains named.
- Freeze the candidate and run a new adversarial review against code, rendered
  artifacts, documentation, gates, and theorem statements. Findings are fixed
  or explicitly accepted in the gap register before publication.
- Keep the remaining generic caller-selected table-identity gap and the absence
  of a formal LLZK semantics prominent. Public readiness does not redefine those
  as solved; current lookup-bearing headlines have circuit-specific resolutions.

## Critical path

```text
P0 public documentation and repository hygiene
  -> A5 renderer + A7 copy-canonicalisation assurance (done)
  -> S25 upstream Clean / Lean alignment (done locally)
  -> L0 LLZK pin review and compatibility run (done locally)
  -> S26 bounded structural U64 and bitwise lowering (implemented locally)
  -> S28 multi-column lookup tables (done locally)
  -> S29 proved witness-visible range contract for XOR (done locally)
  -> P1 Xor32 and BLAKE3.G promotions (done locally)
  -> S29 documentation and evidence closure (`c60d8363`, complete locally)
  -> first frozen R8 candidate rejected; repair and full R8 restart in progress
  -> explicit publication decision
```

S25 was intentionally isolated from capability work: its green bump says the
existing frontend survived upstream change, subject to D026's explicit theorem
boundary. L0 applied the same discipline to the live LLZK delta and advanced
the accepted tool pin to `25fb3740` with same-tree evidence. A5 has already
strengthened the one assurance boundary R7 showed every LLZK binary gate can
miss, and A7 removed the witness reader's remaining inspection-only semantic
premise. S26 and S28 unlock `And8`; S29 Phase B supplies the range contract
D033 exposed. Xor32's external corpus, independent references, concrete theorem
instance, and adversarial gates are complete on `06b80f2f`; exact BLAKE3.G
`G 0 1 2 3` is complete on `a3299ca0`. Documentary closure `c60d8363` completed
S29 and became the first frozen candidate; R8 rejected it. A replacement must
be sealed and the full frozen-tree review restarted before any publication
decision.

## Current scorecard

| Area | State | Evidence or next action |
|---|---|---|
| Stage-1 vertical slice | complete locally | G0-G12 plus the checked showcase on `b16bb83e`; fork CI is behind this branch |
| Public landing page and document map | complete locally | commit `109083ab`; final review still required |
| Checked public example showcase | complete locally | `EXAMPLES.md`; generated from the corpus, enforced by G1, and updated with promoted Xor32 and BLAKE3.G on `a3299ca0` |
| Security and organization settings | prepared locally | commit `29ba5ec2`; activation still requires publication authority |
| CI supply-chain policy | complete locally | commit `9b809e32` had 53 controls; the audit baseline added the public-scope discriminator as control 54; immutable action SHAs and fixed Ubuntu/Rust/Nix-cache inputs; organization CI still required on the frozen SHA |
| Upstream Clean alignment | complete locally | S25; G0-G12 on `6ccca6f8`, `evidence/S25/`; `0e53b9f2` / Lean 4.32.2, D026 recorded |
| LLZK pin review | complete locally | D032; `25fb3740` accepted after both exact outputs passed, then G0-G12 passed on committed pin `5fe8f465`; `evidence/L0/` |
| Structural bitwise witness IR | complete locally | S26/D033; G0-G12 green on `8951f016`, `evidence/S26/` |
| Multi-column tables | complete and adversarially reviewed locally | S28/D034; full 65536×3 certificate, row-preserving G9, six-vector `And8`, and both review repairs passed G0-G12 on `129fbe6e`; `evidence/S28/adversarial-review.md` |
| Headline bitwise examples end to end | complete locally | Xor32 is promoted on `06b80f2f`; exact BLAKE3.G `G 0 1 2 3` is promoted on `a3299ca0`; both have fixed independent outputs, concrete conditional theorem instances, and full external matrices |
| Renderer round-trip assurance | strengthened locally | A5 plus the 2026-08-22 audit: complete constraint/member/parameter readback, public-output checks, and mutation regressions; final G0-G12 result recorded in the audit report |
| Copy-canonicalisation invariant | complete locally | A7; both theorems and G0-G12 green on `a32593bf` |
| Final frozen-tree review | in progress; first candidate rejected | repair, seal a replacement, and restart R8 from the beginning |
| Organization access | available | active `project-llzk` admin verified 2026-08-21 |
| Publication | not authorized | separate final action |

## Publication checklist

Once every acceptance criterion above is met:

1. Choose transfer versus a new `project-llzk/clean-llzk-frontend` repository;
   prefer the descriptive repository unless preserving GitHub's fork relation is
   an explicit requirement.
2. Record the release-candidate commit and all external pins.
3. Create or transfer only after explicit authorization, then apply the
   description, topics, protection, security, and Actions settings in
   `PUBLICATION.md`.
4. Push the frozen commit and require organization-repository CI on that exact
   SHA.
5. Add the LLZK organization-profile link, then verify links, security reporting,
   badges, settings, and CI from an anonymous browser session.
