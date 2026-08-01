# R2 — Stage-1 adversarial acceptance review: verdicts and findings

Reviewed commit: `410343b2cc7fd6d4df2757b312787501eda58c17`
Worktree: `/home/alh/LLZK/clean-llzk-frontend`, branch `clean-to-llzk/integration`
Tools: `/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0` (LLZK 3.0.0)
Evidence: `doc/llzk/evidence/R2/`

## Verdict

**Returned for repair.** No claim in §A is refuted in a way that makes the
*corpus* artifacts unsound — the three emitted modules were hand-checked and are
correct. But A5 is refuted in the generality it is stated in, and four claims
that guard the fail-closed property (§C6, §D2, §D3, §D4) are refuted by working
counterexamples: the backend will emit invalid MLIR and will emit a silently
wrong lookup table, in both cases with no diagnostic. The harness can also be
made to report `PASS` while checking nothing.

The single most important result is not a bug in the code. It is Control 4:
**an `Addition8FullCarry` module with a completely empty `@constrain` passes
G3, G4, G5, G6 and G7 on all six input vectors.** The project states this gap;
it had not demonstrated it. It is now demonstrated, and it bounds what "Stage 1
is complete" can mean.

Counts: 12 CONFIRMED, 8 REFUTED, 6 CONFIRMED-with-caveat, 4 UNSUPPORTED,
0 NOT-CHECKED.

---

## A. Soundness of the emitted constraint system

**A1 — every `assert e` produces a constraint holding iff `e = 0`. CONFIRMED
(for every accepted shape), by construction and by hand-evaluation.**

`Analyze.recognizeOperation` maps `.assert e` to `FieldExpr.ofExpression e`,
which is total over `Expression`'s four constructors and structure-preserving.
`Circuit.lowerConstrain` lowers each to `constrain.eq %e, %zero`. Hand-evaluated
against the gadget source for `Addition8FullCarry`, reading
`Clean/Backend/LLZK/Test/Circuit.lean:157-190`:

| Gadget source | Emitted |
|---|---|
| `lookup ByteTable z` | `constrain.in %v6(@Bytes), %v4(w0)` |
| `assertBool carryOut` | `%v12 = w1 * (w1 + (p-1)*1)`; `constrain.eq %v12, 0` |
| `assertZero (x+y+cin - z - carryOut*256)` | `%v22 = (x+y+cin) + (p-1)*w0 + (p-1)*(w1*256)`; `constrain.eq %v22, 0` |

Three constraints in, three constraints out, each denoting the same polynomial.
`assertBool` arrives as a `FormalAssertion` subcircuit and its single constraint
survives inlining. `Multiply` (`w0 + (p-1)*(x*y) = 0`) and `Decompose` (no
assertions) likewise match their sources exactly.

**A2 — every lookup becomes a `constrain.in` against the table's rows, holding
iff the queried value is a row. CONFIRMED for the operator; the row contents
remain trusted (D012).**

Semantics checked at the pinned revision rather than inferred:
`include/llzk/Dialect/Constrain/IR/Ops.td` at `5db6f8f9` documents
`constrain.in $lhs, $rhs` as "rhs must be contained within lhs", `lhs` an array.
The emitter emits `constrain.in %table, %value` — the correct order, and the only
well-typed one. Arity, row width, uniqueness, symbol legality and non-emptiness
of the registry entry are all checked. What is *not* checked is that the values
are in `[0, p)` — see finding **R2-02**, which is a defect distinct from D012.

**A3 — no Clean constraint is dropped. CONFIRMED.**

`Operations.toFlat` (`Clean/Circuit/Operations.lean:361-367`) is order-preserving
and inlines a subcircuit as `s.ops.toFlat ++ toFlat ops`; nothing is discarded.
`recognizeOperation` matches all four `FlatOperation` constructors exhaustively
(Lean enforces this), and `.interact` is a diagnostic, not a silent drop.
`Analyze.collect` fails the whole compilation if any operation errors, so a
partial `Recognized` cannot be built.

**A4 — no constraint is added that changes what the system proves. CONFIRMED.**

Each output `j` adds a fresh member `@out{j}` and one `constrain.eq %out{j}, %e`.
`@out{j}` occurs in no other constraint, so the system is a definitional
extension: any solution of the original system extends uniquely, and any solution
of the extended system restricts to one. Marking the member `{llzk.pub}` promotes
it to the public interface but does not strengthen the relation over the original
variables. The argument is conservative in both directions.

**A5 — the witness-cell numbering matches Clean's offset allocation for every
accepted circuit shape. REFUTED as stated; CONFIRMED for one-cell witness
operations, which is all the corpus contains.** See finding **R2-03**.

**A6 — reordering into lookups, then assertions, then output equalities cannot
change the meaning. CONFIRMED.**

`ConstraintsHoldFlat` is a conjunction over the operation list
(`Operations.lean:44-51`); conjunction is commutative and every emitted
constraint is closed over values read from `%self` and the parameters, which are
all in scope from the top of `@constrain`. Reordering within `@compute` would
matter — and is *not* done: witness cells keep allocation order there.

---

## B. Faithfulness of the natural division/modulo lowering (D011)

**B1 — `ofNat (mod (val x) (const c))` and `felt.umod ⟦x⟧ c` denote the same
field element. CONFIRMED, subject to one unstated side condition (R2-05).**

Checked against the pinned LLZK source rather than the prose:
`include/llzk/Dialect/Felt/IR/Ops.td` at `5db6f8f9` documents `felt.uintdiv` as
"treats the operands as if they were unsigned integers with bitwidth equal to
that of the prime modulus and performs division rounding towards zero", and
`felt.umod` as its remainder. That is exactly the canonical representative in
`[0, p)`. Checked behaviourally too: `Decompose` is in the corpus with dividend
`p-1`, and both witgen backends agree with Clean there.

**B2 — the two side conditions are sufficient, not merely necessary. CONFIRMED.**

Given `0 < c < p`, both `val x / c` and `val x % c` are `≤ val x < p`, so
`FiniteField.val_fromNat` applies and the result re-enters the field unchanged;
`felt.const c` is not reduced because `c < p`. I could not construct a case
satisfying both conditions that diverges. Note the conditions are checked against
`cfg.field.prime`, and `checkField` is collected in the same pass, so a
configuration whose prime is not the circuit's fails the whole compilation before
any divisor is trusted — there is no path where `checkDivisor` uses the wrong `p`.

**B3 — matching the shape whole is what makes it sound. CONFIRMED.**

`FieldExpr.ofFExpr` accepts exactly two `NExpr` shapes and both bottom out in
`.val x` with `x` field-sorted, recursively recognized by the same function. No
`NExpr` constructor is ever lowered; no natural-sorted value is ever
materialized. A nested `ofNat (mod (val (ofNat (mod (val y) (const 3)))) (const c))`
stays field-valued at every `ofNat`, so the property is preserved under nesting.

**C5's sub-question, answered here:** yes, the corpus does test a dividend whose
canonical representative is near `p` — `Decompose` vector 5 is `2013265920 = p-1`.

---

## C. What the gates actually establish

**C1 — G3/G4 pass on every emitted artifact. CONFIRMED, reproduced.**
`bash scripts/llzk/e2e.sh` from this commit: `PASS: G0 G1 G2 G3 G4 G5 G6 G7`,
exit 0, 3 circuits, 16 vectors. Transcript in `evidence/R2/e2e-reproduced.txt`.

**C2 — G5/G6/G7 establish witness agreement and nothing more. CONFIRMED, and
now demonstrated rather than asserted.** Controls 3 and 4 (below) show the gates
stay green under a wrong `@constrain` and under an empty one.

**C3 — the witness gates are falsifiable. CONFIRMED; two new controls added.**
Control 1 reproduced (red, exit 1). Control 2 was not re-run: it requires editing
`Differential.witness`, outside this review's scope, and Controls 1 and 3
exercise the same comparison path. New: Control 3 (wrong coefficient in
`@constrain` only — stays green) and Control 4 (empty `@constrain` — stays
green). Control 5 is in §C6.

**C4 — every rejection path has a fixture, and every fixture's message is
accurate. CONFIRMED for messages, REFUTED for coverage.** All six negative
fixtures state accurately why the construct is rejected. But the count is wrong
and the coverage is partial — see **R2-11** and **R2-07**.

**C5 — the 16 vectors exercise the boundaries that matter. CONFIRMED for
`umod`/`uintdiv`; UNSUPPORTED for out-of-assumption behaviour.**
`Decompose` covers `0`, `255/256/257`, `65535` and `p-1`; `Multiply` covers
`0`, `p-1`, and `(p-1)^2` (which is also the only thing in the repository that
behaviourally pins babybear's modulus). Nothing tests `Addition8FullCarry`
outside its `Assumptions`: all six vectors have `x, y < 256` and `carryIn ∈ {0,1}`.
Since `llzk-witgen` ignores `constrain()`, an out-of-assumption vector would only
compare witness generators, so this is a small gap — but it is the gap where the
gadget's `Spec` stops holding, and a reader could mistake green for "the gadget
is correct outside its range".

**C6 — `e2e.sh` cannot pass while skipping a check. REFUTED.** See **R2-06**.

---

## D. Fail-closed completeness

**D1 — every constructor of `FExpr`, `VExpr`, `WitgenIR`, `Step`,
`FlatOperation` is accepted with a fixture or rejected with a diagnostic.
CONFIRMED at the code level; REFUTED at the fixture level.**

Enumerated against `Clean/Circuit/WitnessIR.lean`:

- `WitgenIR`: `native` rejected, `ir` accepted. Both handled.
- `Step`: `letF`/`letN` both rejected by the `steps.isEmpty` test.
- `VExpr`: `lit` accepted, `mapRange` and `append` rejected by name.
- `FExpr` (12 constructors): all 12 named individually by `describeFExpr`;
  the match is exhaustive, so Lean enforces completeness.
- `NExpr` (14 constructors) and `BExpr` (7): unreachable except through
  `FExpr.ofNat`/`ite`; the two accepted shapes are matched and everything else
  falls to one message.
- `FlatOperation` (4): all four handled, `.interact` diagnosed.

Two deviations from the module's own stated principle ("kept exhaustive rather
than falling back to a generic message"): `Step` and `NExpr` rejections do not
name the constructor. Fixture coverage is six of roughly seventeen distinct
rejection paths — **R2-07**.

**D2 — no input can reach `Print` that renders to invalid LLZK. REFUTED**, twice
and independently: **R2-01** (component name) and **R2-04** (the `@compute`/
`@constrain` parameter lists, whose counterexample is checked into the repository
as a passing golden).

**D3 — names the backend generates are always legal MLIR symbols. REFUTED.**
See **R2-01**. `Table.isSymbolName` exists and is applied to table names only.

**D4 — `Config` cannot be set to something that produces wrong-but-accepted
output. REFUTED.** See **R2-02**.

---

## E. Design and quality

**E1 — D005–D014 are each implemented as described and still the right call.
REFUTED for D005; three arguments against, below.**

*Against D005.* The claim that malformed LLZK is unrepresentable is false in two
ways (**R2-04**), and one of them is demonstrated by a golden test inside the
repository. The IR does buy real properties — the `Option (Value × Ty)` result
and the two component builders are genuinely load-bearing — but the decision log
should say what it rules out (return-type/terminator disagreement, functions that
are neither compute nor constrain) rather than "a struct that is not a valid
LLZK component cannot be built", which is not true.

*Against D008.* Giving every output its own `{llzk.pub}` member is sound (A4) and
the rationale is good, but it interacts badly with the one thing outside the
repository that consumes these modules: the extra `constrain.eq` per output
doubles the public surface a downstream analyser has to reason about, and the
members are written in `@compute` *and* constrained in `@constrain`, so
`--llzk-enforce-no-overwrite`-style checks see a shape the rest of the ecosystem
does not produce. The alternative D008 rejects (mark the witness cell) is indeed
worse; the option it does not consider is emitting outputs as `@compute`'s
*return value* rather than as members. Worth reopening once a downstream consumer
exists.

*Against D014.* "The comparison is therefore against Clean's proved witness
semantics" overstates what `witgen_eq_dynamicWitnesses` gives. It proves the
array interpreter equals `dynamicWitnesses`. It says nothing about
`localWitnesses` — the definition `ElaboratedCircuit` and the completeness
statements actually use — and those two definitions come apart on exactly the
circuits described in **R2-03**. D014 should name `dynamicWitnesses` as the
reference and record that the backend's `@compute` implements a third thing.

*Also stale:* D006 attributes the attribute derivation to `Builder.function`,
which S04 removed; it now lives in `Builder.assemble`.

**E2 — exactly one definition of each thing that must not drift. REFUTED.**
Three `#guard`s on `ExportTable.ofStatic tinyStatic` are duplicated verbatim
between `Examples.lean:106-108` and `Test/Circuit.lean:122-124`. Layout names,
the field registry and the accepted subset are each defined once — that part
holds.

**E3 — no dead code, no speculative generality. REFUTED.** See **R2-08**.

**E4 — docstrings state facts that are true now. REFUTED.** See **R2-09**.

**E5 — module boundaries hold. CONFIRMED with one exception.** `IR` contains no
rendering; `Print` is the only renderer; `Basic` imports nothing at all, let
alone from Clean. The exception: `Table.isSymbolName` is a statement about MLIR
symbol syntax living outside `Print` — and it is precisely the check that should
have been reused for the component name (**R2-01**). Separately,
`Analyze.lean`'s "the analysis is the *only* capability gate" contradicts
`Circuit.lean`'s own docstring, which correctly notes that `FieldExpr.lower` can
also refuse.

**E6 — the Lean is idiomatic for this codebase. CONFIRMED.** No `sorry`,
`partial`, `unsafe`, `panic!`, `.get!` or `[]!` anywhere under `Clean/Backend/`
(the only grep hit is the word "partial" in an `EmitMain.lean` docstring). Naming,
docstring density and `Except`-based error handling match the surrounding code.
`Spec := True` on the fixture circuits contradicts `AGENTS.md`'s rule that specs
state meaning, but the file says so explicitly and the reason is sound. One
placement objection: `moduloByZero`, `divideByPrime` and `tinyStatic` are used
only by `Test/Circuit.lean`, yet they sit in `Examples.lean`, which
`Clean.lean` imports — so deliberately-broken fixtures ship in the library. The
stated reason for the move (goldens and corpus share one definition) is true of
`multiply`, `decompose` and `byteTable`, and false of these three.

---

## F. Control-plane integrity

**F1 — `CURRENT.md` is accurate and a fresh session could resume from repository
files alone. REFUTED, at the first command.** R2's own packet says
"Base integration commit: `a0c86278…` — verify with `git rev-parse HEAD`". At
this commit `git rev-parse HEAD` is `410343b2` (the R2 bootstrap itself), so the
instruction cannot succeed. `CURRENT.md` separately records the integration
commit as `0f4f5705`, a third value. Everything else in `CURRENT.md` reproduced:
pins, the provisioning path, the gate table, and the "what is still not
established" list, which is honest and accurate.

**F2 — every session packet's Handoff matches its commit. UNSUPPORTED — not
checkable from repository files.** Every packet says "Resulting commit: recorded
in `doc/llzk/CURRENT.md`", and `CURRENT.md` records only the latest integration
commit. Nothing links S03 to `b75a5125`, S06 to `1c1cf413`, and so on, except
git log subject lines. Spot-checking those subject lines against `git show
--stat` for S03 and S06 found no discrepancy, but the control the claim describes
does not exist.

**F3 — evidence files record what was run and the numbers match a re-run.
CONFIRMED.** `evidence/S02/gates.txt` matches the reproduction exactly, including
the vector and module counts, and its "what this does not establish" section is
accurate.

**F4 — the recorded deviations are complete. REFUTED.** See **R2-10** and
**R2-12**.

**F5 — no result the project depends on exists only outside the repository.
CONFIRMED with one accepted exception.** The LLZK tools live in `/nix/store`,
which is correct and is documented in `PINS.md` with the acquisition command and
the cache-key requirement. Everything else — corpus, goldens, harness, expected
witnesses — is generated from repository files.

---

## Findings

Ordered by severity.

### R2-01 (High) — the component name is never checked, so the backend emits invalid MLIR

`LLZK.compile`/`emit` take `name : String` and drop it, unvalidated, into
`struct.def @{name}`, `llzk.main = !struct.type<@{name}>` and every
`!struct.type<@{name}>` operand type. `Table.isSymbolName` exists and is applied
to table names; it is not applied here.

    #eval IO.print (emit babybear "not a symbol" multiply)
    → module attributes {llzk.lang, llzk.main = !struct.type<@not a symbol>} {
        struct.def @not a symbol {

No diagnostic. This directly refutes D2, D3, and the fail-closed property as
stated in `Basic.lean` ("a non-empty diagnostic array means no LLZK text is
produced" — here text is produced and there is no diagnostic).

Fix: reuse `isSymbolName` on `name` in `Analyze.recognize` (or in `compile`),
with the same diagnostic wording as the table check. One-line change plus a
negative fixture.

### R2-02 (High) — table row values are not range-checked and are silently reduced mod p

`ExportTable`'s docstring states "Values are canonical representatives in
`[0, p)`". `ExportTable.diagnose` — which is documented as "everything wrong with
one registry entry" — checks the name, the arity, emptiness and row width, and
does not check the values. `Config.tables` is the documented, and for
`Gadgets.ByteTable` the *only*, way to supply rows (D012).

    diagnose { name := "Bytes", arity := 1,
               rows := (Array.range 256).map (fun i => #[i + 2013265921]) }
    → #[]

and the emitter produces `global.def const @Bytes : !array.type<256 x
!felt.type<"babybear">> = [2013265921, …]`. `llzk-opt` accepts it unchanged.
Downstream, `felt` literals denote their residue, so the emitted lookup table is
a different set from the one the author wrote — and in the example above it is
*accidentally* the right one, which is the worst case for noticing.

This is not D012. D012 is "we cannot check the rows are the table's rows". This
is "we do not check the values are field elements", which the backend absolutely
can check and already claims to.

Fix: one loop in `ExportTable.diagnose` requiring every value `< p`. Note this
needs the prime, so `diagnose` gains a parameter or moves behind
`diagnoseRegistry cfg`.

### R2-03 (Medium-high) — the lowering's environment is more permissive than Clean's witness generator

`Circuit.lowerCompute` pushes each witness cell into the environment as soon as
it is computed, across the whole flattened cell list. Clean's
`FlatOperation.dynamicWitness` (`Clean/Circuit/Basic.lean:366-371`) evaluates a
`.witness m compute` against `ProverEnvironment.fromList acc`, where `acc` is the
prefix *before* the operation — the block's own cells are not in scope and read
as `0`.

So for a `.witness m` block with `m ≥ 2` whose cell `j` reads circuit variable
`inputSize + i` for some `i < j` in the same block, the emitted `@compute` and
Clean's `witgen` compute different witnesses. The backend accepts such a circuit
silently: `FieldExpr.lower` only rejects references to *later* cells.

Clean has a name for the discipline this violates —
`Operations.ComputableWitnesses` (`Basic.lean:387-390`), "witness generators only
depend on the environment at indices smaller than the current offset" — and
`Addition8FullCarry.lookupCircuit` proves it. The backend never checks it.

Reachability is low: constructing such a circuit needs an explicit
`Expression.var` at a computed offset inside a multi-cell witness, which Clean's
authoring surface does not make easy, and all three corpus circuits use `m = 1`.
But claim A5 is stated for "every accepted circuit shape", and this refutes it.

Compounding: `Recognized.witnesses` is a flat array, so the block structure
needed to make the check is discarded by `Analyze` before `Circuit` runs. The fix
is therefore not local to `lowerCompute` — either `Recognized` keeps the block
boundaries, or `Analyze` rejects intra-block back-references at recognition time
(it has the block and the running offset there).

`Differential.witness` uses the same `witgen`, so gate G7 would catch this — but
only on a vector, and only if such a circuit were in the corpus. It is not.

### R2-04 (Medium-high) — D005 is overclaimed, and the repository contains a passing golden that is invalid LLZK

Two ways malformed LLZK is representable:

1. **`@compute` and `@constrain` parameter lists are not tied together.**
   `Builder.computeFunction` and `Builder.constrainFunction` each take their own
   `Array ParamSpec`, and `StructDef` stores two independent `Func`s. LLZK
   requires `@constrain`'s argument types, minus `%self`, to equal `@compute`'s.
   `Circuit.lower` happens to pass `inputSpecs r fieldTy` to both, so real
   lowerings are fine — but not by construction.

   The counterexample is checked in: `Clean/Backend/LLZK/Test/Print.lean`'s
   `@Demo` gives `@compute` two parameters and `@constrain` one. Feeding the
   golden's own expected text to `llzk-opt`:

       error: expected "@constrain" function argument types (sans the first one)
              to match "@compute" function argument types

   exit 1, for both plain verify and `--verify-roundtrip`. Adding the missing
   parameter makes the same text verify and round-trip cleanly, so that is the
   only defect in it. The golden passes G2 today because G2 compares text to
   text and never asks a tool.

2. **`Builder.fresh` is public, and allocation is not definition.** IR.lean's
   docstring says "only `Builder.fresh` produces one, so a lowering cannot invent
   an undefined SSA name". `fresh` allocates an index; it does not emit a
   defining statement. `constrainFunction` itself relies on that (for `%self`),
   so any caller can do the same and reference an undefined `%vN`.

Fix for (1): make `StructDef` — or a single `component` builder — own one
parameter-specification list and hand it to both function builders, which is what
D005 already claims. Fix for the golden: correct `demoConstrain` to take the same
two parameters, and add the Print golden to the artifacts `e2e.sh` feeds to
`llzk-opt`, which its own docstring already claims happens (see R2-09).

### R2-05 (Medium) — D011's soundness rests on an unstated property of `FiniteField.val`

D011 argues that `FiniteField.val x` "is the canonical representative in
`[0, p)`, which is exactly the operand interpretation LLZK's `umod`/`uintdiv`
use". `Clean/Utils/FiniteField.lean` defines `FiniteField` as an abstraction over
prime *and binary* fields; its laws are `val_lt`, `val_injective`,
`val_fromNat`, `val_zero`, `val_one`. **None of them says `val` is the ring
representative** — i.e. that `val (a + b) = (val a + val b) % size`. `val_fromNat`
only inverts `fromNat` below the size.

The backend is generic over `[FiniteField F]` and only checks
`FiniteField.size F = cfg.field.prime`. Size `p` does force `F ≅ 𝔽_p`, but it
does not force this particular `val` to be the isomorphism. The same gap applies
to `FieldExpr.ofExpression`'s `.const c ↦ felt.const (val c)`, which assumes
`felt.const n`'s meaning (`n mod p`) agrees with `val`.

In practice Clean's instance for `F p = ZMod p` uses `ZMod.val` and everything is
fine — the corpus confirms it behaviourally. The finding is that this is a *side
condition of the translation that is nowhere stated*, and that G7 cannot detect
its violation because `Differential.witness` goes through the same `val`/`fromNat`
(the blind spot D014 already records for names, applied to arithmetic).

It matters concretely for the S08/P5 plan: the preservation theorem for D011
cannot be proved generically over `FiniteField`. Either the emitter is restricted
to a class carrying the extra law, or D011 records the assumption explicitly.

### R2-06 (Medium-high) — `e2e.sh` can be made to report PASS while checking nothing

`require_llzk_sibling` establishes `llzk-witgen`'s provenance by requiring it to
sit in the same directory as a version-checked `llzk-opt`. A directory containing
a symlink to the real `llzk-opt` and a two-line `exit 0` script named
`llzk-witgen` satisfies it:

    PASS: G0 G1 G2 G3 G4 G5 G6 G7
      3 circuit(s), 16 input vector(s), both witgen backends.
    exit 0

G5, G6 and G7 are vacuous and the summary still claims 16 vectors on both
backends. C6 is refuted.

The co-location reasoning in `lib.sh` is sound as far as it goes — the comment
correctly explains that `llzk-witgen --version` reports nothing usable — but
provenance is not the property the gate needs. The property it needs is *this
binary discriminates*.

Fix: a self-test before the loop. Run `llzk-witgen` once against a deliberately
wrong `--check-output` file and require a non-zero exit; abort if it succeeds.
That is four lines, it costs one extra invocation, and it makes every subsequent
green meaningful.

### R2-07 (Medium) — fixture coverage of the rejection paths is about a third

Six negative fixtures exist. Rejection paths with no fixture:
`.native` witness programs; `let`-steps; `mapRange`; `append`; `.interact`;
multi-column lookup queries; lookup arity mismatch; empty table; duplicate table
names; and `FieldExpr.lower`'s "reads circuit variable N, which no input or
earlier witness defines" — which is the *only* failure the lowering itself has
and is untested.

`ROADMAP.md`'s completion table cites "eight negative fixtures" as the evidence
that "unsupported cases fail with structured diagnostics". Given R2-01 and R2-02,
that row does not hold as stated.

### R2-08 (Low-medium) — dead code and unused public API

- `FeltBinOp.sub` and `FeltBinOp.div`: no lowering can produce them.
  `FieldExpr` has no subtraction or division constructor, and `FieldExpr.lower`
  emits only `add`, `mul`, `uintdiv`, `umod`. They are reachable only from
  `Test/Print.lean`.
- `Differential.publicOutputsJson`: defined, referenced nowhere. `e2e.sh` uses
  `--output-scope=full-witness` exclusively.
- `Circuit.diagnostics` and `Analyze.analyze`: `diagnostics` has no caller, and
  `analyze` has exactly one — `diagnostics`. The pair is D009's "inspect the
  capability boundary without building a module" entry point, and nothing uses
  it.
- `FieldSpec.ofPrime?`: no caller.
- Four of six registry fields (`koalabear`, `goldilocks`, `bn254`, `grumpkin`)
  are unexercised by any circuit. Unlike the above this is defensible — a
  registry is a table — but see R2-13.

### R2-09 (Low-medium) — stale and false docstrings

- `Corpus.lean:22` — "Every artifact `lake exe llzk-emit` materializes". There is
  no such executable; `lakefile.lean` is unchanged from the base and S07's
  handoff records that a `lean_exe` was deliberately removed. Line 49 of the
  same file gives the correct command.
- `Test/Print.lean:11-13` — "it is valid LLZK, so `scripts/llzk/e2e.sh` can also
  feed it to `llzk-opt` as a syntax check". Both halves are false: `e2e.sh` only
  globs `.lake/llzk/*.llzk`, which the Demo module is not among, and `llzk-opt`
  rejects it (R2-04).
- `EmitMain.lean:19` — "Nothing partial is left that a harness could mistake for
  a passing check". A failing entry does leave its `.llzk` and any
  already-written vectors on disk; what saves the harness is `set -e` plus the
  non-zero exit, not the absence of partial output.
- `Analyze.lean:12` — "The analysis is the *only* capability gate" contradicts
  `Circuit.lean:9-11`, which correctly says the lowering has one genuine failure.
- `DECISIONS.md` D006 — attributes the attribute derivation to `Builder.function`,
  removed in S04.
- `Differential.lean:70-73` — "Numbers here, because this is `llzk-witgen`'s
  input format". See R2-14: numbers are not accepted above 64 bits, and the
  reason the *output* uses strings applies identically to the input.

### R2-10 (Low-medium) — undocumented deviations from the ARCHITECTURE §5 contract

`ARCHITECTURE.md` §5 is the accepted design baseline (per `PROVENANCE.md`,
"where they contradict them, the contradiction is a defect to be resolved by a
decision entry"). Three contradictions have no decision entry:

- the root component is named `@Main` in the contract; the emitter names it after
  the circuit. This one has a measured cost — see R2-12.
- `llzk.lang = "clean"` in the contract; the emitter emits the bare unit
  attribute `llzk.lang`. (`llzk-opt` accepts the string form.)
- `llzk.fields = [#felt.field<"babybear", 2013265921>]` in the contract; not
  emitted. Here the deviation is *forced* — declaring a registry field conflicts
  with the built-in definition — which is exactly the kind of thing a decision
  entry should record, because it is a fact about LLZK that was learned and is
  now nowhere written down.

D008 does cover the fourth deviation (`{signal}`/`@out{j}` instead of the
contract's `{llzk.pub}` witness members), and `ROADMAP.md` covers the missing
`Command.lean`.

### R2-11 (Low) — miscounts in the control plane

- `ROADMAP.md` and `CURRENT.md` both say "eight negative fixtures". There are
  six.
- `CLAIMS.md` §G says "3 `#guard`s". There are six — three in `Examples.lean`
  and a verbatim copy in `Test/Circuit.lean` (E2).
- `CLAIMS.md` §G's other scope facts are correct: 14 modules, 2065 lines,
  10 `#guard_msgs`, the three-line diff outside `Clean/Backend`, and the absence
  of `sorry`/`partial`/`unsafe`/`panic!`/`.get!`/`[]!` all verified.

### R2-12 (Medium) — the emitted modules cannot enter any LLZK analysis pipeline, and a partial constraint check was available and unevaluated

`llzk-opt --llzk-product-program` — the entry point for
`--llzk-to-smt-no-cf`, and hence for `llzk-smt-check`, which ships in the same
`bin/` directory as the pinned tools — hard-requires a root struct literally
named `Main` and ignores `llzk.main`:

    $ llzk-opt --llzk-product-program .lake/llzk/Multiply.llzk
    error: could not find root struct "Main"        exit 1

    $ sed 's/@Multiply/@Main/g' … | llzk-opt --llzk-product-program
    exit 0

With that one rename, the full pipeline runs and produces an SMT-LIB encoding
with the paired `w0_c`/`w0_w`, `out0_c`/`out0_w` variables that a determinism
(under-constrainedness) check needs:

    $ llzk-opt --llzk-full-inlining --llzk-product-program --llzk-to-smt-no-cf Main.llzk
    exit 0

This does not close the §A gap — it checks determinism of the emitted system, not
equivalence with Clean's — and it has a hard limit: `constrain.in` and
`global.read` are unhandled by the SMT lowering, which warns
"analysis may be incomplete" and then exits 1 on `Addition8FullCarry`. So it
would cover `Multiply` and `Decompose` and not the Stage-1 target circuit.
`--llzk-print-interval-analysis` was also tried and is uninformative on the
emitted form (everything `Entire`).

The finding is not "you missed a gate". It is that `CURRENT.md`, `GATES.md`,
`DECISIONS.md` D014 and `ROADMAP.md` all state the gap as though the pinned
toolchain offers nothing at all against `constrain()`, and no session recorded
having looked. It offers something partial, with sharp limits worth writing down,
and the reason the artifacts cannot use it is a naming deviation the project did
not know it had made (R2-10).

### R2-13 (Low) — the registry is correct, and nothing in the repository would notice if it were not

Checked both ways, and it passes: all six `FieldSpec` entries match
`lib/Util/Field.cpp` at the pinned revision exactly, and all six were confirmed
behaviourally by computing `(p-1)^2 = 1` through `llzk-witgen`.

The asymmetry worth recording: a *wrong* transcription is fail-open in one
direction. A circuit over the true prime would be rejected by `checkField`
(fail-closed, fine), but a circuit over the mistranscribed prime would be
accepted and emitted as `!felt.type<"name">`, and LLZK would then do arithmetic
in the real field — silently wrong, and exactly what D010 exists to prevent. Only
`babybear` is pinned behaviourally today, by `Multiply` vector 3.

Cheap fix: five more corpus entries, or one `#guard`-style table of
`(p-1)^2 = 1` checks.

### R2-14 (Low) — `Differential.inputsJson` will break on three of the six registry fields

`inputsJson` emits input values as `Json.num`. `llzk-witgen --inputs` rejects
JSON numbers that do not fit its integer path:

    goldilocks, arg0 = p-1 as a number → error: expected felt value as JSON
                                         integer or decimal string
    goldilocks, arg0 = p-1 as a string → {"out0":"1"}

Same for `bn254` and `grumpkin`. The docstring's rationale for the *output*
encoding ("it avoids any question of precision for the larger primes in the
registry") applies verbatim to the input and was not applied. Latent: the corpus
is babybear-only today. Fix is one word.

### R2-15 (Low) — control-plane bookkeeping

- **S06 has no session packet.** `doc/llzk/sessions/` holds S00, S01, S02, S03,
  S04, S05, S07 and R2. S06 is real work — commit `1c1cf413`,
  `evidence/S06/gates.txt`, and D012/D013 are attributed "Enacted by: S06" — and
  no deviation records the omission. This is itself an undocumented deviation
  from `ORCHESTRATION.md`, so it also refutes F4.
- **No session records its resulting commit.** All eight say "recorded in
  `doc/llzk/CURRENT.md`", which records only the current integration commit. F2
  is not checkable as designed.
- **R2's own bootstrap instruction is wrong**: "Base integration commit
  `a0c86278…` — verify with `git rev-parse HEAD`" cannot hold at the commit that
  introduced it. A third value, `0f4f5705`, is what `CURRENT.md` calls the
  integration commit.
- **`ROADMAP.md` declares "Stage 1 is complete"** in bold, and lists R2 as
  outstanding four paragraphs earlier. The acceptance review is the thing that
  decides that question; the roadmap should state the criteria and let R2 record
  the verdict.

---

## What went right

Worth stating plainly, because a findings list is not a summary.

- The three emitted modules are correct. `Addition8FullCarry`'s constraints were
  hand-evaluated against the gadget source and are exactly its three constraints,
  with the right coefficients and the right lookup operand order.
- Every claim the project makes about what it has *not* established is accurate.
  `CURRENT.md`'s "what is still not established", `GATES.md`'s "what G5–G7 do not
  establish", D014's closing paragraph and `e2e.sh`'s own trailing note all say
  the same true thing, and no document overstates the assurance. That is rarer
  than it sounds and it is why this review could be targeted.
- The two semantic arguments that were flagged as prose (D011, D010) both survive
  checking against the pinned LLZK *source*, not just against the prose. D011's
  whole-shape recognition is genuinely the right design and genuinely sound;
  D010's registry is transcribed correctly in all six entries.
- The fail-closed architecture (D009: recognize into a closed language, then lower
  totally) is the right shape, and it is why R2-01 and R2-02 are one-line fixes
  rather than redesigns.
- Evidence reproduced exactly. `evidence/S02/gates.txt` matched a fresh run,
  including counts.

---

## Recommended follow-up sessions

One per finding or tightly related group, as the packet requires.

| Packet | Findings | Why this grouping |
|---|---|---|
| **S08 — close the two fail-open name/value checks** | R2-01, R2-02 | Both are missing validations in `Analyze`/`Table`, both are one loop plus a negative fixture, and both break the fail-closed property that everything else rests on. Do these first. |
| **S09 — make the harness discriminate** | R2-06, R2-14 | A witgen self-test before the loop, and the `--inputs` encoding. Both are `scripts/llzk` + `Differential` changes with no semantic risk. |
| **S10 — the witness-block environment** | R2-03, and D014's wording | Needs a design choice (keep block structure in `Recognized`, or reject at recognition time), so it deserves its own packet rather than being bundled. |
| **S11 — IR invariants and the Print golden** | R2-04, R2-08 (`sub`/`div`) | Tie the two parameter lists together, fix the golden, add it to `e2e.sh`'s artifact set, and drop what the tie-up makes unreachable. |
| **S12 — the SMT track** | R2-12, R2-10 | Rename the root component to `@Main`, record the decision, and evaluate `--llzk-product-program → --llzk-to-smt-no-cf → llzk-smt-check` as a real gate for the lookup-free circuits. This is the only finding that could *reduce* the §A gap before the proof track lands. |
| **S13 — documentation and control plane** | R2-05 (state the assumption), R2-07, R2-09, R2-11, R2-13, R2-15 | All text and fixtures; no code semantics change. |

The G9 proof baseline should follow S10 and S12, not precede them: S10 settles
what `@compute` is supposed to mean, and R2-05 settles what class the
preservation theorem can even be stated over.

---

## Control-set coverage

`CONTROL-SET.md` was opened only after everything above was written. Six
suspicions; this review found two of them independently and missed four.

| Control | Found independently? | Where |
|---|---|---|
| S1 — struct name never validated as an MLIR symbol | **yes** | R2-01, with a worked counterexample |
| S2 — table name could collide with the struct name | **no** | — |
| S3 — the renderer golden has never been through `llzk-opt` | **yes** | R2-04 and R2-09; and it is worse than suspected |
| S4 — zero-of-everything edge cases untested | **partly** | answered incidentally, not raised as a gap |
| S5 — an output that is an input, or a constant, untested | **no** | — |
| S6 — `Ty` derives `Inhabited` | **no** | — |

### The four misses, now checked

**S2 — CONFIRMED as a real defect, same class as R2-01.** A component whose name
equals a table's name produces a module `llzk-opt` rejects:

    $ sed 's/@Addition8FullCarry/@Bytes/g' Addition8FullCarry.llzk | llzk-opt
    error: symbol "@Bytes" references a 'global.def' but expected a 'struct.def'

`diagnoseRegistry` checks table names for uniqueness among themselves and not
against the component name. Fold this into R2-01's fix: the component name must
be a legal symbol *and* must not collide with any registered table.

Why I missed it: I checked which names reach the output and stopped at "is it a
legal symbol", never asking whether the module's symbol table could have two
entries with one name. The method gap is that I reasoned about each name in
isolation rather than about the namespace they share.

**S4 — no defect; the questions have answers.** `llzk-opt` accepts a `struct.def`
with no members, a `@compute` with no parameters, and a `@constrain` with no
constraints — established while repairing the `Test/Print.lean` golden
(`demo-fixed.llzk` verifies and round-trips with `@Empty` intact). A circuit with
zero witness cells is also fine, established by S5's `@Passthrough`. A circuit
with zero *inputs* remains untested. Corpus gap, not a defect.

**S5 — no defect; D008's justifying case works.** Compiled two circuits, an
input passthrough (`main x := pure x`) and a constant output
(`main _ := pure (.const 7)`):

    @Passthrough  verify=0  roundtrip=0
    @ConstOut     verify=0  roundtrip=0

`@Passthrough` emits a component with no `{signal}` members at all and a single
`constrain.eq %out0, %arg0`; `@ConstOut` emits `constrain.eq %out0, %(felt.const 7)`.
Both are exactly what D008 says should happen, and neither had ever been
exercised. This should be two corpus entries — they are the cheapest possible
coverage of the decision D008 is *about*, and they cost nothing.

Why I missed it: I read D008, agreed with its argument, verified A4 abstractly,
and did not ask which of the shapes it enumerates the corpus actually contains.
The method gap is that I checked the reasoning and not its coverage.

**S6 — CONFIRMED as stated, and it is a non-issue with a real point behind it.**
`IR.lean:38` — `Ty` derives `DecidableEq, Repr, Inhabited`. `Value`'s `Inhabited`
was deliberately removed in S04 so no caller could conjure an SSA value; `Ty`'s
remains. Unlike `Value`, a default `Ty` cannot silently corrupt a lowering — every
`Ty` in the emitter comes from `cfg.field.name` or from the struct name, and a
`default : Ty` would render as `!felt.type<"">`, which `llzk-opt` rejects. The
point that survives is the one the control makes: the reasoning that removed one
instance should be written down against the other, or the asymmetry explained.
Fold into S13.

### What this says about the review

Two of the four misses (S2, S5) are the same failure mode: I verified that each
mechanism is *right* and did not systematically ask what the corpus and the
fixtures actually *reach*. R2-07 records that gap for the rejection paths, where
I did notice it; I did not apply the same enumeration to the accepted paths.

A method that would have caught both: enumerate every case each decision
(D005–D014) claims to handle, and mark each as fixture-covered, corpus-covered,
or neither — the same table §D1 got, applied to acceptance rather than rejection.
That is a cheap, mechanical pass and it should be part of the next review packet.

The control set's own closing note — "if the review finds only these, it has
almost certainly not been adversarial enough; none of them is in section A" —
is discharged. Fourteen of the fifteen findings are not in the control set, and
the review's two most consequential results are §A/§C results the control set
does not touch: R2-03 (the witness-block environment, the only §A refutation) and
Control 4 (an empty `@constrain` passing every tool gate).
