# R5 — the maximal adversarial review

Status: bootstrapped  
Tree under review: **frozen**; see `Frozen at` below. It will not change while
R5 runs. R4's reviewers both had the tree rewritten under them mid-session and
had to re-verify every finding against a moving target; that does not happen
again.

## Why this review exists

`CURRENT.md` claims a specific and fairly strong assurance position. R2 → R4
established that this project's failure mode is **not** bad code — it is *claims
stated more strongly than the code supports*. Both of R4's severe findings were
of that kind:

- D019 said a typeclass was required at every entry point. It appeared in **zero**
  elaborated signatures, because `variable [C F]` is dropped unless the instance
  is used. A field with a non-representative `val` compiled to a wrong module
  with both halves of G9 green.
- `Config.field` was documented as protecting against arithmetic in the wrong
  field. It compared only the prime, so a babybear circuit emitted as
  `!felt.type<"bn254">` passed `llzk-opt`, both witgen backends, both halves of
  G9, and G10.

Three rounds of self-review missed both. So R5's central instruction is:
**attack the claims, not the code.** For every assertion in the documentation and
the docstrings, find the elaborated reality and see whether they match.

## The claim inventory

Each lens gets a list of specific written claims to falsify. They are quoted from
`DECISIONS.md`, `GATES.md`, `CURRENT.md`, `ROADMAP.md` and the module docstrings.
A finding is *"claim X is false, here is the counterexample"*, not *"this code
could be nicer"*.

Priority order, highest first:

1. **Anything a theorem is claimed to establish.** Read the statement, not the
   name or the docstring. Ask: is it vacuous? Is a hypothesis unsatisfiable? Does
   it quantify over what the prose says it does? Is it *instantiated* anywhere?
2. **Anything claimed to hold "by construction" or to be "impossible".** D005's
   bullets, D015's "no name to validate", D018/D020's "no module leaves this
   backend without…", the private-constructor invariants.
3. **Anything claimed to be enforced by the type system.** `#check` the
   elaborated signature. This is where both severe R4 findings lived.
4. **Anything claimed to be checked.** Find the check, then find the input it
   does not reject.
5. **Anything claimed to be covered by a gate.** Make the gate go green while the
   property is false.

## Standing rules

- **Read-only.** Copy to a scratch directory to mutate anything.
- **Construct counterexamples.** A finding without one is a suspicion; say which
  it is.
- **Report what survived**, and what you did to try to break it. A claim nobody
  attacked is not evidence.
- **`#print axioms` everything** you rely on.
- The tree is frozen. If a file appears to change, that is a bug in this setup —
  say so.

## The control set

Not read by the reviewers. Kept here to measure R5's own coverage afterwards, the
way `CONTROL-SET.md` measured R2's. Written before the reviews returned.

<!-- CONTROL SET — do not read while reviewing
C1. `ConstraintSet.ofSource` reads `Config.tables` for the globals, so the
    Clean side of the lookup comparison is caller input, not the circuit. A
    wrong `Config` is compared against itself.
C2. `Corpus.registryEntry` builds a `Recognized` by hand and goes through
    `lowerRecognized`, so six of eleven artifacts have no G9 at all — and
    `EmitMain` only errors on `some false`, never on `none`.
C3. `FieldExpr.lower_spec` is proved but *used* by nothing; G9 still does the
    work at every compile.
C4. `WitnessSet.agree` compares trees syntactically, so a commuted product in
    `@compute` would be a spurious mismatch. Nothing tests that.
C5. `Print` renders `Member.name` and `ParamSpec.argName` unescaped; they are
    generated today, so it is latent, not live.
C6. The goldens are regenerated from the emitter by a script, so G2 cannot
    detect an emitter error, only drift — and the script is not in the repo.
C7. `readStmt` models only `feltConst` and `feltBin`; `lower_spec`'s statement
    is therefore about a reader that would ignore a `readMember` if one appeared.
-->

## Frozen at

Commit: `e56d9e12` (`S20: prove the expression lowering emits what the reader
reads back`), plus this packet.

Reproduce: `LLZK_OPT=… LLZK_WITGEN=… bash scripts/llzk/e2e.sh` →
`PASS: G0 … G10`, exit 0, 11 circuits, 30 vectors.
