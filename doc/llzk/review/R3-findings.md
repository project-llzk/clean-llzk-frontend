# R3 — review of the R2 repair

Reviewed: the S08–S15 repair, in the worktree, against
`review/R2-resolution.md`'s claims.

R2's own closing note said its two worst misses shared one method gap: it
verified that each mechanism was *right* without asking what the corpus and
fixtures actually *reach*. That gap applies to a repair session at least as
much, so this review spent its effort on two things — trying to falsify the
resolution table, and enumerating what the new code's branches reach.

**Verdict: three defects, all in S15's new code, all fixed. Three documented
gaps closed by S16–S18 rather than carried.** No claim in `R2-resolution.md`
survived unchecked, and one was found to be understated.

## Defects found

**R3-01 — a vacuous guard in `ConstraintSet.ofModule`.** It checked
`params.size = slots.size`, where `slots.size` is *defined* as
`1 + (params.size - 1)`. The check could not fail. Replaced with a check that
every parameter after `%self` carries a felt type, which is the property the
reader actually relies on when it maps parameter `i` to circuit variable `i-1`.

**R3-02 — `global.read` of an undefined name was accepted.** The reader recorded
the table name without checking the module defines a `global.def` for it,
leaving that to `llzk-opt`. That is a real hole in a reader whose whole job is to
be an independent second opinion: it now checks against `Module.globals`.

**R3-03 — the falsifiability control set had no wrong-table case.** Every
perturbation exercised the *equalities*; the one that exercises the lookup's
table name was missing, so "the comparison is on the name as well as the
polynomial" was untested. Added.

## One claim was understated

`Poly.lean` said canonicity was "not load-bearing", which is true of soundness
and was hiding a property worth having. Stress-testing the normal form showed it
absorbs commutativity, associativity, distributivity and cancellation: eight
terms summed in all eight rotations and in reverse normalise to the same
seven-term polynomial, strictly sorted, no zero coefficients, no duplicate
monomials. That is what stops G9 producing *spurious* mismatches, and it is now
pinned — together with two negative checks, without which those guards would be
satisfied by a normal form that collapses everything.

## Branch coverage of the new code

Enumerated rather than assumed, which is the method R2 said it should have used.

`ConstraintSet.step` has eight cases. Six are reached by the corpus:
`feltConst`, `feltBin .add`, `feltBin .mul`, `readMember`, `globalRead`,
`constrainEq`, `constrainIn`. Two are fail-closed backstops nothing reaches:
`feltBin .uintdiv/.umod` (witness-only, so they cannot appear in `@constrain`)
and `structNew`/`writeMember` (which belong to `@compute`). The same is true of
the four `guard`s and of `compileSource'`'s refusal branch: **the mismatch
diagnostic is unreachable while the lowering is correct**, which is the point of
a backstop but means it is exercised only by the `cross` controls, which drive
the comparison directly rather than through the emitter.

That is stated rather than papered over. It is the honest limit of translation
validation as built: the *check* is tested in both directions, the *refusal* is
not, because nothing can make the emitter emit a wrong module.

## The three gaps the repair documented rather than closed

R2-resolution listed these as "what this repair did not do". Leaving them there
would have been a second round of the same thing R2 criticised, so:

**D012's lookup rows — closed by S16.** The obligation is one sentence, and one
sentence can be a `Prop`. `ExportTable.Certifies` is it;
`ofStatic_certifies` discharges it for any single-column `StaticTable`, and
`byteTable_certifies` for `Gadgets.ByteTable` — the case D012's follow-up called
open. It did not need `ByteTable`'s `StaticTable` to be named after all:
`StaticTable.toTable` defines `Contains` from the `row` function alone, and
`contains_iff` already relates that to `x.val < 256`. Residual: the compiler
does not *demand* a certificate, because `Config.tables` takes bare
`ExportTable`s and tying one to a lookup needs the `Table` that `RawTable`
erased.

**G9's scope — closed by S17.** Not with the `BuilderM` simulation argument the
resolution said it needed, but by making the check a precondition of emission:
`compile` and `emit` refuse to return a module that fails it. That is
translation validation rather than a verified translator, and it is weaker in
one way and stronger in the way that mattered — it holds for every circuit
rather than the five in the corpus. Recorded as D018, with what it trades away.

**R2-05's field law — closed by S18.** `FiniteField`'s laws do not make `val`
the ring representative, so D011's argument had a side condition that could not
even be *stated*. `CanonicalRepr` states it, `val_natCast` shows the two laws
pin `val` down, and every recognizer and entry point now requires it — so a
field that lacks it is a type error rather than silently wrong arithmetic.
Recorded as D019.

## One thing the axiom check surfaced

Every theorem added by S15–S18 depends only on `propext`, `Quot.sound` and (for
some) `Classical.choice`. One instantiation does not:
`Examples.byteTable_certified`, the certificate at `pBabybear`, additionally
carries `primeBabybear` and `Fact (pBabybear > 512)`, which Clean proves by
`native_decide`. The generic `byteTable_certifies` is clean; the `native_decide`
comes from `Clean/Utils/Primes.lean` and is inherited by any proof about a
concrete Clean prime field. Pre-existing and untouched by this work, but it is in
the trusted base of every concrete claim here and so is recorded rather than left
for a reader to notice.

## What R3 did not do

- It did not re-run R2's §A hand-evaluation of `Addition8FullCarry`'s
  constraints. It no longer needs to: G9 does that comparison mechanically, on
  every compilation, and `Test/Constraints.lean` pins that it can fail.
- It did not review S16–S18, which it prompted. Those are new code, reviewed
  only by the session that wrote them, and the same argument that produced this
  review applies to them.
- It is not independent. It was written by the session that wrote the repair.
  That is worth less than R2 was, and the residual list in `CURRENT.md` should
  be read with that in mind.
