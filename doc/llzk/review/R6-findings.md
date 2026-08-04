# R6 — adversarial review of Stage 1, and its repair

**Date:** 2026-08-04
**Tree reviewed:** `4e15d3ad` on `clean-to-llzk/integration`, working tree clean
**Tools:** the pinned `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0`
**Method:** reproduce the gates first, then read every backend module against the
claims made about it, then attack the claims with the binaries rather than with
argument. Every finding below was demonstrated, not inferred.

## What held

Stage 1 reproduces. `bash scripts/llzk/e2e.sh` printed
`PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12` on the reviewed commit before
any change, on this machine, with the pinned binaries: 11 circuits, 30 vectors,
both witgen backends, 30 harness error paths.

Four things were attacked specifically and did not move:

- **D019 survives elaboration.** R4a-1's trap — a `variable [C F]` binder dropped
  because the instance is never used — is the failure most likely to come back,
  because it is invisible in source. `#check` on all eleven entry points D019
  names shows `[CanonicalRepr F]` in every elaborated signature, including
  `compile`, `emit`, `emitSource`, `verify` and `Corpus.Entry.ofSource`.
- **The G9 readers do not share a blind spot that matters.** `ConstraintSet.ofModule`
  re-derives input, witness and output counts from the module; `step` is
  fail-closed on every statement form it does not model, `uintdiv`/`umod`
  included; `memberVar` requires the member to be declared. The Clean side uses
  Clean's own `FlatOperation.constraints`/`lookups`, which are the extractors
  `constraintsHoldFlat_iff_forall_mem` is stated over.
- **`Poly`'s soundness does not depend on canonicity**, as its docstring says. A
  false *accept* would need two different constraint systems to produce identical
  `Poly` data, and identical data denotes identical functions by the `eval`
  theorems. Canonicity only buys the absence of spurious refusals.
- **`Source.ofFormalCircuit` uses Clean's own flattening convention**, byte for
  byte: `(c.main (varFromOffset Input 0)).operations (size Input) |>.toFlat`,
  which is what `Clean/Circuit/WitnessExport.lean`'s four `WitgenOps` instances
  do. This is the one place a bug would be invisible to G9 — both readers descend
  from `Source` — so it is worth saying that it is not a re-derivation.

## Findings

Six, all fixed in this session. None is a soundness break in the emitted
modules; three are claims stated more strongly than the code supported, which is
the failure mode R5 named and which this round found again in three new places;
two are gates that did not exist; one is a harness defect that blocked the
project's own documented resume path.

### R6-1 — `reclaim` was dead code for every identity it was written for

**Severity:** harness, blocking. **Status:** fixed, D024.

`lock_is_live` decides liveness with `kill -0`, which needs a numeric session id,
and fails closed when it cannot decide. An `LLZK_SESSION` id is opaque, so for
exactly the sessions D023 introduced that variable for — agent sessions and CI —
a lock could never be reclaimed, `claim` printed the live-holder refusal whose
only advice is "wait", and `status` reported "held" for a liveness it had never
observed. The only exit was `rm`, which D023 does not mention.

Demonstrated by walking into it: S24's lock had sat on the tree since
2026-08-02, `CURRENT.md`'s "Next session" begins "claim the worktree first", and
the claim, the reclaim and the status were all wrong in the way above. G11 did
not catch it because all three of its stale-lock cases record owner `999999`.

Worse, the *existing* case named "reclaim while the holder is live" was written
with `LLZK_SESSION=owner`, so it was exercising the undecidable path while
claiming to exercise the live one — the one G11 case that touched this, and it
was testing the wrong branch.

Fixed by `reclaim --from <recorded-owner-id>` (D024), with six new G11 cases and
the mislabelled one split into a genuinely-live case using this shell's POSIX
session id. G11 is now 39 error paths.

### R6-2 — GAPS.md item 2's counterexample is false

**Severity:** claim. **Status:** fixed, with a verified replacement.

The renderer gap was witnessed by "a `Stmt.render` that swapped `constrain.in`'s
operands would pass G2, G3 and G4". It would not. Run against the pinned
`llzk-opt` on `Addition8FullCarry.llzk`:

```
constrain.in %v4, %v6 : !array.type<256 x …>, !felt.type<"babybear">
  error: use of value '%v4' expects different type than prior uses
constrain.in %v4, %v6 : !felt.type<"babybear">, !array.type<256 x …>
  error: custom op 'constrain.in' invalid kind of Type specified
```

The operands have different types, so G3 catches it in both spellings.

The gap is real and the correct witness is sharper: `readMember`, `constrainEq`
and `constrainIn` are emitted **only** into `@constrain`, so a rendering bug in
any of them cannot surface in `@compute`, where the differential lives. Two
mutations verified against the pinned tools:

| mutation | G3 | G4 | G10a | G5/G6 |
|---|---|---|---|---|
| every `struct.readm %self[@w{k}]` rendered as `@w0` | pass | pass | pass | pass |
| every `constrain.eq` line dropped | pass | pass | pass | pass |

The second is R2's Control 4 reached through the renderer instead of the
lowering, and G9 cannot see either because G9 compares `Module`s.

### R6-3 — Clean's core byte-identity was an invariant with no gate

**Severity:** ungated invariant. **Status:** fixed, in G0.

GAPS.md lists "Clean's core is byte-identical to the pinned base" among the
things that held under attack, and two decisions argue *from* it: D012's
follow-up defers naming `ByteTable`'s `StaticTable` because that belongs to a
Clean-side session, and GAPS item 8 defers removing `Primes.lean`'s
`native_decide` uses for the same reason. Both arguments evaporate if the premise
does, and nothing checked the premise.

It was true — `git diff` against `1e563b9c` touches nothing under `Clean/` beyond
`Clean/Backend/LLZK/`, `Clean.lean` and `Clean/Test.lean` — which is exactly why
it would have regressed unnoticed. `check-pins.sh` now fails on core drift, with
those two registration files as the only exceptions, and G11 drives it against a
clone with a touched `Primes.lean`.

### R6-4 — `copyCell`, the one shape this project misread, reached no LLZK tool

**Severity:** coverage. **Status:** fixed.

`Examples.lean` opens by claiming every circuit in it is consumed by both the
golden tests and the conformance corpus. `copyCell` was in neither. Its only
reference anywhere was a single `#guard` in `Test/WitnessCheck.lean`.

That is the circuit R5c used to break the witness reader: a proved
`FormalCircuit` whose *correct* module the backend refused, blaming itself. Its
emitted module — the one where `@compute` writes the parameter straight into
`@w0` and `@out0`, so the artifact genuinely cannot distinguish the cell from the
input — had never been parsed by `llzk-opt`, never round-tripped, never admitted
to the analysis pipeline, and never run through either witgen backend.

Now a corpus entry (`CopyCell`, three vectors) and a golden. Corpus counts move
to 12 circuits / 33 vectors / 10 SMT lowerings.

### R6-5 — ROADMAP.md overstated four gaps that later sessions had closed

**Severity:** claim. **Status:** fixed.

Its "What is still not established" still said the witness side has no G9 (S19
and D020 built it), that there are 27 vectors (30), that the compiler does not
demand a table certificate (S24 made `CertifiedConfig` the type of every public
entry point), and that `Addition8FullCarry` is untested outside its
`Assumptions` (three of its nine vectors are). Its completion table still
claimed "19 negative fixtures, one per rejection path" — a claim R5 withdrew,
because it found three reachable paths with no fixture at all.

This is R5's failure mode running the other way: a register that overstates gaps
teaches a reader to discount it, which is how the two understated ones survived.
The section now points at GAPS.md and says a disagreement between them is a
defect in ROADMAP.

### R6-6 — two smaller stale statements

**Severity:** claim. **Status:** fixed.

- `Circuit.lean`'s closing note said `compile` and `emit` live in
  `Constraints.lean`. They moved to `WitnessCheck.lean` when D020 added the
  witness half, which is the whole reason that half is a precondition of
  emission.
- `CURRENT.md` said 24 negative fixtures. There are 25.

## Looked at, and left alone

Recorded in GAPS.md so the next reviewer does not re-derive them:

- `Builder.assemble` bounds a body's operands above but not below, so a `Value`
  imported from another component with a *low* index would alias. Unreachable —
  `Circuit.lean` builds one component and never holds two.
- Neither G9 reader compares member counts against writes. Both derive from
  `r.witnesses.size` on the supported path.

## Verification

`bash scripts/llzk/e2e.sh`, pinned tools, after the repair:
`doc/llzk/evidence/R6/gates.txt`. The mutation experiments behind R6-2 are
reproducible from a corpus emitted with
`lake env lean --run Clean/Backend/LLZK/EmitMain.lean <dir>`; the commands are in
`doc/llzk/evidence/R6/renderer-mutations.md`.
