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
- Licensing and upstream Clean attribution remain intact. A repository
  description, topics, contribution path, security-reporting path, and branch
  protection are prepared before publication.

### 2. Meaningful, demonstrable progress

- Preserve the Stage-1 vertical slice: `Addition8FullCarry` compiles, the LLZK
  tools accept it, both witness engines agree with Clean, and the typed module's
  constraints imply the gadget's semantic `Spec` under named hypotheses.
- Align to current upstream Clean before adding capability (S25).
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
- Publish a small checked example table generated from, or pinned by, repository
  tests. Do not use hand-maintained coverage counts as evidence.

### 3. High assurance with honest boundaries

- Keep G0-G12 green and falsifiable; all negative fixtures and agreement-count
  pins remain green.
- Close the renderer gap for the `@constrain`-only statement forms before the
  release candidate: parse rendered `readMember`, `constrainEq`, and
  `constrainIn` back into the typed representation and check their round trip, or
  adopt an equivalently strong reviewed construction.
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
  -> S25 upstream Clean / Lean alignment
  -> L0 LLZK pin review and compatibility run
  -> S26 structural U64 and bitwise lowering
  -> S28 multi-column lookup tables
  -> P1 promote headline examples into the full corpus
  -> A5 renderer round-trip assurance
  -> R8 frozen-candidate adversarial review
  -> explicit publication decision
```

S25 is intentionally isolated from capability work: a green bump says the
existing frontend survived upstream change. L0 applies the same discipline to
the live LLZK delta and either retains or advances the accepted tool pin with
evidence. S26 and S28 together create the impactful example increment. A5 then
strengthens the one assurance boundary R7 showed every LLZK binary gate can
miss.

## Current scorecard

| Area | State | Evidence or next action |
|---|---|---|
| Stage-1 vertical slice | complete locally | `CURRENT.md`, R7, G0-G12; fork CI is seven commits behind |
| Public landing page and document map | in progress | this branch |
| Upstream Clean alignment | pending explicit pin decision | S25 |
| LLZK pin review | not started | live `main` is 25 commits ahead; isolate after S25 |
| Structural bitwise witness IR | pending S25 | S26 |
| Multi-column tables | pending S26 | S28 |
| Headline bitwise examples end to end | not started | promote after S28 |
| Renderer round-trip assurance | not started | A5 / `GAPS.md` section 2 |
| Final frozen-tree review | not started | R8 |
| Organization access | available | active `project-llzk` admin verified 2026-08-21 |
| Publication | not authorized | separate final action |

## Publication checklist

Once every acceptance criterion above is met:

1. Choose transfer versus a new `project-llzk/clean-llzk-frontend` repository;
   prefer the descriptive repository unless preserving GitHub's fork relation is
   an explicit requirement.
2. Record the release-candidate commit and all external pins.
3. Confirm the full local gate run and organization-repository CI on that same
   commit.
4. Configure the repository description, topics, default branch, branch
   protection, security reporting, and the LLZK organization profile link.
5. Push or transfer only after explicit authorization, then verify links and
   badges from an anonymous browser session.
