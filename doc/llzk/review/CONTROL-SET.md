# Control set — open only after your own review is written down

This file exists to measure the review's coverage, not to guide it. Reading it
first defeats its purpose and biases the review toward a short list someone else
happened to notice.

**Protocol:** complete the review, record every finding with a verdict, commit
or at least write it out. *Then* read this file. Anything here you did not find
independently is a gap in the review method — record that as a finding about the
review, and say what would have caught it.

---

## Provenance

Written by the implementing session immediately before handing over, from
suspicions raised in the first few minutes of a self-review that was then stopped
in favour of an unanchored one. **These are unverified.** Some are probably
non-issues; at least one may be wrong in the other direction, i.e. worse than
described. They are recorded as suspicions with the evidence that raised them,
not as findings.

## S1 — The struct name is never validated as an MLIR symbol

`Table.isSymbolName` guards table names. Nothing appears to guard the `name`
argument to `LLZK.compile`, which becomes `struct.def @<name>`, `llzk.main` and
every `!struct.type<@…>`.

Suspected consequence: `compile cfg "My Circuit" c` emits unparseable text, and
the failure surfaces as an `llzk-opt` parse error rather than a backend
diagnostic. Fails closed via the tool, but violates the project's own rule that
the backend refuses before rendering.

Check: pass a name with a space, a leading digit, and an empty string.

## S2 — A table name could collide with the struct name

Both `global.def const @X` and `struct.def @X` live in the module's symbol table.
`diagnoseRegistry` checks table names are unique among themselves, not against
the component name.

Check: compile a circuit named `Bytes` that also looks up the `Bytes` table.

## S3 — The renderer golden module has never been through `llzk-opt`

`Clean/Backend/LLZK/Test/Print.lean`'s module docstring says the `@Demo`/`@Empty`
module "is valid LLZK, so `scripts/llzk/e2e.sh` can also feed it to `llzk-opt` as
a syntax check that does not depend on any gadget."

`e2e.sh` does no such thing — it only checks `LLZK.Corpus.corpus`, and the
renderer golden is not in it. So the claim is false as written, and the one
module that exercises *every* IR constructor (including `felt.sub`, `felt.div`,
`array.type`, an empty-member struct and a parameterless `@compute`) is the one
module no tool has validated.

Check: read `e2e.sh`; feed the golden text to `llzk-opt` by hand.

## S4 — Zero-of-everything edge cases are untested

No corpus entry has zero inputs, zero witness cells, or zero outputs. The
renderer covers an empty-member struct only in the unvalidated golden (S3).

Check: does `llzk-opt` accept `struct.def` with no members? A `@compute` with no
parameters? Does `@constrain` with no constraints verify?

## S5 — An output that is an input, or a constant, is untested

D008 justifies giving outputs their own members precisely because an output need
not be a witness cell. Every corpus circuit returns witness cells.

Check: a circuit whose output is an input passthrough, and one whose output is a
constant.

## S6 — `Ty` derives `Inhabited`

`Value`'s `Inhabited` was deliberately removed so no caller could conjure a
silently wrong SSA value. `Ty` still derives it. Probably harmless — but the
reasoning that removed one should be applied to the other or explicitly
distinguished.

## Coverage note

This list is short and was produced in minutes. If the review finds only these,
it has almost certainly not been adversarial enough — none of them is in
section A of `CLAIMS.md`, which is where an actual soundness bug would live.
