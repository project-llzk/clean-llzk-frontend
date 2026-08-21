# Public-readiness milestone

Updated: 2026-08-21

Status: active

Target: a frozen release-candidate commit suitable for an organization-owned
repository under `project-llzk`

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
- The branch is aligned with the accepted upstream Clean revision, has a clean
  worktree, contains no generated build products, and has no unpublished commits
  that are part of the release candidate.
- Licensing and upstream Clean attribution remain intact. **Prepared locally:**
  `PUBLICATION.md` specifies the repository description, topics, branch
  protection, required checks, and security settings; `CONTRIBUTING.md`, the PR
  template, and `SECURITY.md` supply the contribution and vulnerability paths.
  Private reporting must still be enabled during the authorized publication
  action.

### 2. Meaningful, demonstrable progress

- Preserve the Stage-1 vertical slice: `Addition8FullCarry` compiles, the LLZK
  tools accept it, both witness engines agree with Clean, and the typed module's
  constraints imply the gadget's semantic `Spec` under named hypotheses.
- **Done locally:** align to current upstream Clean before adding capability
  (S25, exact fetched head `0e53b9f2`, Lean 4.32.2).
- Review the LLZK toolchain pin after S25 and before capability work. As of
  2026-08-21, `project-llzk/llzk-lib` `main` is 25 commits past the accepted
  `5db6f8f9` pin and includes changes in LLZK transforms and `llzk-witgen`.
  Retaining the reproducible 3.0.0 pin or advancing it must be an explicit,
  separately gated decision; "main moved" is not by itself a reason to discard a
  known toolchain.
- Retire the two capability blockers identified by R7: structural `U64Expr`
  lowering with bitwise/conditional support (S26), then multi-column lookup
  tables and their certificates (S28).
- Promote at least `Xor32` and one composed bitwise gadget (`BLAKE3.G` or
  `Keccak256.Theta`) from the checked coverage sweep into the end-to-end corpus.
  Each promoted example must reach `llzk-opt`, both witness backends, the Clean
  differential, and the source-to-module checks; a compile-only `#guard` is not
  release evidence.
- **Done locally:** publish a small checked example table generated from, or
  pinned by, repository tests. `EXAMPLES.md` is generated from
  `LLZK.Corpus.corpus`; G1 requires byte equality and `Test/Showcase.lean` pins
  its denominator and labels. Do not use hand-maintained coverage counts as
  evidence.

### 3. High assurance with honest boundaries

- Keep G0-G12 green and falsifiable; all negative fixtures and agreement-count
  pins remain green.
- Keep the A5 renderer check on the release path: rendered `readMember`,
  `constrainEq`, and `constrainIn` are parsed back into the typed representation
  and must round-trip before text is returned.
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
- Keep the remaining upstream table-identity gap and the absence of a formal
  LLZK semantics prominent. Public readiness does not redefine those as solved.

## Critical path

```text
P0 public documentation and repository hygiene
  -> A5 renderer + A7 copy-canonicalisation assurance (done)
  -> S25 upstream Clean / Lean alignment (done locally)
  -> L0 LLZK pin review and compatibility run
  -> S26 structural U64 and bitwise lowering
  -> S28 multi-column lookup tables
  -> P1 promote headline examples into the full corpus
  -> R8 frozen-candidate adversarial review
  -> explicit publication decision
```

S25 was intentionally isolated from capability work: its green bump says the
existing frontend survived upstream change, subject to D026's explicit theorem
boundary. L0 applies the same discipline to
the live LLZK delta and either retains or advances the accepted tool pin with
evidence. A5 has already strengthened the one assurance boundary R7 showed
every LLZK binary gate can miss, and A7 removed the witness reader's remaining
inspection-only semantic premise. S26 and S28 together create the impactful
example increment.

## Current scorecard

| Area | State | Evidence or next action |
|---|---|---|
| Stage-1 vertical slice | complete locally | G0-G12 plus the checked showcase on `b16bb83e`; fork CI is behind this branch |
| Public landing page and document map | complete locally | commit `109083ab`; final review still required |
| Checked public example showcase | complete locally | `EXAMPLES.md`; generated from the corpus, enforced by G1, green on `b16bb83e` |
| Security and organization settings | prepared locally | commit `29ba5ec2`; activation still requires publication authority |
| CI supply-chain policy | complete locally | commit `9b809e32`; immutable action SHAs, fixed Ubuntu/Rust/Nix-cache inputs, 53 G11 controls; organization CI still required on the frozen SHA |
| Upstream Clean alignment | implementation complete; full evidence pending | S25; `0e53b9f2` / Lean 4.32.2, D026 recorded |
| LLZK pin review | preflight complete; next after S25 evidence | `sessions/L0-review-llzk-pin.md`; exact 25-commit risk inventory and same-tree matrix |
| Structural bitwise witness IR | pending L0 | S26 |
| Multi-column tables | pending S26 | S28 |
| Headline bitwise examples end to end | not started | promote after S28 |
| Renderer round-trip assurance | complete locally | A5; G0-G12 green on `28132f64` |
| Copy-canonicalisation invariant | complete locally | A7; both theorems and G0-G12 green on `a32593bf` |
| Final frozen-tree review | not started | R8 |
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
