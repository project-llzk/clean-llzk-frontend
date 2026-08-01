# R5 — five independent reviews, consolidated

Reviewed: `faaf5309`, frozen throughout. Five lenses: theorem statements (R5a),
documentation versus elaborated reality (R5b), red team (R5c), gate
falsification (R5d), trusted base (R5e).

**Verdict: returned for repair, with one soundness break.** R2 through R4 never
produced a module that was actually wrong; R5 did.

## Process failure, first

The control set was written as an HTML comment *inside* `R5-packet.md`, and
reviewers were told to read that file. Two of them read the control set — one by
`sed`-stripping the marker, one because it is simply in the file. **R5's coverage
measurement is void**, and the control set has been moved to
`R5-control-set.md`, which no packet points at. The findings themselves stand on
their own evidence; the meta-measurement does not.

## X1 (SOUNDNESS) — a `Config` can weaken the emitted constraint system, and every gate stays green

Found independently by R5a-1 and R5c-BREAK-1.

```
fatBytes := { name := "Bytes", arity := 1, rows := (Array.range 512).map (#[·]) }
LLZK.compile { field := .babybear, tables := #[fatBytes] } Addition8FullCarry  →  .ok
```

The emitted module carries `global.def const @Bytes : !array.type<512 x …>` and a
`constrain.in` against it. `arg0=255, arg1=45, arg2=0, w0=300, w1=0` satisfies
every emitted constraint; Clean's `ByteTable.Contains` rejects it. So the module
admits `out0 = 300` where the gadget's `Spec` says `44`. Both halves of G9 green,
`llzk-opt --verify-roundtrip` and `--llzk-product-program` green.

**The `ConstraintSet.globals` conjunct, added in the R4 round to close exactly
this, is a self-comparison.** `ofSource.globals` reads `cfg.tables`; the module's
globals are built by `lower` from `Recognized.tables`, which `recognize` builds
from `cfg.tables` with the same filter. On the only path that exists, the
conjunct is a tautology.

**And its falsifiability control is a sham.** `Test/Constraints.lean` compiles
with `withBytes` and compares against `oneRowBytes` — two different configs,
which production never produces. The attack it purports to cover, compiling
*with* the bad config, was never run.

This is the same error this project has spent four rounds criticising, committed
while fixing an instance of it: the test exercised the comparison, not the path.

D012 is right that the backend cannot tie an `ExportTable` to the `Table` a
`RawTable` erased. What is new is that the mechanism claiming to compensate does
nothing, and said so in a docstring.

## X2 (COMPLETENESS) — a proved `FormalCircuit` is refused, and told it is a backend bug

Found independently by R5a-6, R5b-2 and R5c-BREAK-2.

```lean
def copyCircuit : FormalCircuit (F pBabybear) field field where
  main x := do let y ← witness x; y === x; return x
```

`LLZK.emit` refuses it: *"the emitted @compute does not compute the circuit's
witnesses … This is a defect in the backend, not in the circuit: please report
it."* The emitted module is **correct**; the reader is wrong.

`WitnessSet.step`'s `writeMember` case rebinds the written SSA value's slot to
`cell (inputSize + k)`. When a cell's expression is a bare `.var`,
`FieldExpr.lower` returns the *existing* parameter rather than emitting anything,
so the rebind clobbers that parameter for the rest of `@compute`.

Fail-closed — R5c checked the dual and confirmed it cannot produce a false
accept. But it is a false "file a bug" for a legal circuit, and the natural
workaround is X3's unvalidated door.

It also refutes `verify`'s docstring — *"Nothing the emitter produces can fail
this"* — which is what justified never testing that branch against real emitter
output.

## X3 — public doors around G9

`GATES.md` still says `compile`/`emit` are "the only public entry points"; D018
already retracted that wording and `GATES.md` was not updated. Public and
unchecked:

| Door | What it skips | Found by |
|---|---|---|
| `compileSource` | both halves; takes a Clean `Source`, exactly what the claim quantifies over | R5b-1 |
| `lowerRecognized` | both halves, and the D011 divisor/constant side conditions | R5a-8, R5c-3, R5d-6 |
| `verify` | the constraint half — its docstring says it prevents R2's empty-`@constrain` attack; it does not | R5c |
| `Module.render` | everything | R5e |

R5d rebuilt R2's Control 4 through `lowerRecognized`: `Multiply` with its
multiplication constraint deleted, passing G3, G4, G5, G6, G10a, G10b.

Six of the eleven corpus artifacts go through `lowerRecognized`, and `EmitMain`
guards on `= some false`, which `none` is not. So the harness banner — "no module
leaves this backend without them" — is false for six of the eleven modules the
same run certifies.

**X3b — `lowerRecognized` emits text that traps or silently lies.** D011's two
side conditions are checked in `Witness.ofFExpr`, i.e. only on the `recognize`
path. Through `lowerRecognized`: divisor `0` emits `felt.uintdiv %v0, 0`, which
every static gate accepts and `llzk-witgen` traps on; divisor `p+5` emits
`felt.const 2013265926`, which LLZK reduces to `5`, so `7 % (p+5)` silently
computes `7 % 5 = 2`. Both with an empty diagnostic array.

## X4 — the harness self-tests generalise from one input shape

R5d's through-line, five instances, each a working `PASS: G0 … G10`, exit 0:

| # | The self-test never exercises… | Consequence |
|---|---|---|
| D-1 | `--backend=execution-engine` | G6 can be a stub; log differs from baseline only in tool paths |
| D-2 | anything but a *non-MLIR* file | a generic MLIR parser passes; G3's "verifies" is false while green |
| D-3 | `--llzk-to-smt-no-cf` | G10b fabricatable, and the floor *rewards* it (13 > 9) |
| D-4 | any artifact but the alphabetically first | a wrapper honest on that one probe skips 12 of 13 modules |
| D-5 | a scratch filename it does not choose | two 6-line shims defeat both self-tests |

Plus: `reason="$(…)"` under `set -e` kills the shell before G10b's "not for any
declared reason" message can print — the diagnostic is dead code;
`check-pins.sh` calls `llzk_fail` without sourcing `lib.sh`; no floor on artifact
or vector count.

## X5 — `FieldExpr.lower_spec` is far weaker than its docstring

R5a abstracted the statement over the lowering function and **proved it of five
alternatives**, no `sorry`, clean axioms: one that throws on every expression;
one that ignores `ty` and emits everything as `bn254`; one that appends a bogus
`constrain.eq %v, 0` for every subexpression; one that emits junk
`struct.writem`s; one that redefines an already-defined SSA index.

`readStmt` is the identity on `structNew`, `readMember`, `writeMember`,
`globalRead`, `constrainEq` and `constrainIn`, and `Stmt.dst?` is `none` for
three of them, so arbitrarily many such statements are invisible to all three
conjuncts. The reading claim also sits entirely under `out = .ok v`.

R5a-4 further shows the conjuncts **cannot** compose into a whole-function
statement: `readStmts` over a real `@constrain` body extracts no constraints at
all; every `env` entry in `constrainBody` is a `readMember` result the reader
ignores; and the bounds do not imply distinctness, which `ofModule` requires.

So S20-as-planned was lifting almost nothing, and `IR.lean`'s claim that
`Constraints.lean` instantiates the reader is false — `lower_spec` has no
consumer anywhere.

## X6 — the renderer is outside every theorem

R5e. `emit = renderResult (compile …)`; every theorem stops at the `Module`.
Nothing says `Module.render` is faithful. For `@compute` that is covered
empirically, because G5–G7 execute the text. For **`@constrain` nothing covers
it**: a `Stmt.render` that swapped `constrain.in`'s operands would pass G2
(goldens are the renderer's own output), G3/G4 (well-formed, round-trips), G5–G7
(compute untouched), G9 (compares `Module`s, never text) and G10.

`Print.lean` guards the converse — "equal modules render to equal strings". The
hazard is unequal modules rendering to equal text, or text LLZK reads
differently. Undocumented.

## X7 — the chain to Clean's actual soundness does not exist

R5e. `ConstraintsHoldFlat` is not `ConstraintsHold.Soundness`. Bridging needs the
lookup half (admitted missing), `ops.FullGuarantees`, and the offset
correspondence. `grep` for `Soundness|Spec` across the backend returns no
theorem. "The emitted constraints hold ⇒ the gadget's `Spec` holds" is neither
proved nor listed as missing.

## X8 — smaller, all real

- **G9 reads no `Ty`.** A babybear circuit typed entirely `bn254` passes both
  `agree` checks; only `checkField` catches it, which G9's summary rows obscure.
- **CI does not run `e2e.sh`.** G0, G3–G7 and G10 have no automation at all.
- **Three reachable rejection paths have no fixture**, including the
  registry-membership branch that was R4's severe finding's own repair.
- **Docs stale or wrong**: `CURRENT.md` two commits behind and contradicting
  D021 about whether S20 exists; `GATES.md` carrying retracted wording; "27
  vectors" (30); the module map missing three files; "one per rejection path".
- **D019's "every recognizer"** is false — the entry points carry
  `CanonicalRepr`, the recognizers do not, and `Expression.lean` still has the
  literal dropped-`variable` pattern on `ofExpression`.
- **D020 misattributes `WExpr.eval_ofWitgen`**, which carries no canonicity
  content and would hold for a permuted `val`.
- **`byteTable_lookup_iff`'s `hdiag` is never discharged**; "discharged by the
  compiler" is the wrong word for a hypothesis.
- **`native_decide`** is in the trusted base of every concrete claim and appears
  in no standing account. R5e notes it looks removable: five of the eight uses in
  Clean's `Primes.lean` are literal `Nat` comparisons `decide` would close.

## What survived, and it is substantial

- **Clean core is byte-identical to the pinned base.** No definition was bent to
  fit; verified by `git diff`.
- **`CanonicalRepr` is genuinely enforced** at every entry point; R4a-1's attack
  is dead, and the two laws really do pin `val` for a prime field.
- **D017's `felt.umod`/`uintdiv` reading confirmed on all six registry fields**,
  not just babybear — 12/12 through both witgen backends. New evidence beyond
  what G5–G7 cover.
- **No false accept in the polynomial comparison.** R5c could not construct two
  semantically different sources whose constraint sets collide, nor a mismatched
  (source, module) pair `agree` accepts. Every route to a wrong constraint system
  went through X1's `cfg.tables` channel, not the algebra.
- **Witness differential clean on eight hostile sources** — multi-cell blocks,
  nested `umod`, cross-block reads, boundary divisors, 200×200 with a
  20 000-node expression — all valid LLZK, all backends agreeing.
- **R2-03 block-local enforcement correct**; degenerate shapes all emit valid
  LLZK; the table-name policy admits nothing that breaks MLIR; `--check-output`
  rejected all eight under-specification attacks; the R4b-5 tolerance-list fix is
  sound.
- Every `Poly`/`WExpr`/`TableCert` evaluation theorem held under direct attack.

## Repair order

1. **X2** — the rebind. A legal circuit is being refused today.
2. **X1** — stop the false claim, force the certificate on the supported path,
   and replace the sham control with one that compiles with the bad config.
3. **X3/X3b** — close or properly gate every public door; move D011's side
   conditions to a `Recognized` validator.
4. **X4** — make each self-test exercise the shape the gate it guards uses.
5. **X5/X6/X7/X8** — withdraw the overclaims, then decide what to prove.
