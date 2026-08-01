import Clean.Backend.LLZK.Corpus

/-!
# Gate G9: the emitted constraints, checked against Clean's

Runs `ConstraintSet.agree` — the polynomial comparison in
`Clean/Backend/LLZK/Constraints.lean` — over every corpus circuit that has a
Clean source, at compile time.

This is the gate that would have caught R2's Control 4, the
`Addition8FullCarry` module with a completely empty `@constrain` that passed
every other gate on all six input vectors. No tool in the pinned LLZK toolchain
looks at `constrain()`; this does.

## The gate is checked to be falsifiable

A green that cannot go red is decoration — `GATES.md` says so about the witness
gates, and the same standard applies here. The second half of this file perturbs
the *Clean* side in each of the ways the emitter could plausibly get the emitted
side wrong, and pins that the comparison goes red for every one:

| Perturbation | The emitter bug it stands for |
|---|---|
| drop every assertion | an emitted `@constrain` that is missing constraints — Control 4 |
| bump one coefficient | a wrong constant in a lowered expression — Control 3 |
| duplicate every assertion | a constraint emitted twice, or once too few |
| drop the lookup | a `constrain.in` that never got emitted |
| compare against another circuit | the whole comparison being vacuous |

The perturbations are applied to the Clean source rather than to the module
because `StructDef` and `Func` have private constructors and can only be built by
`Builder.component` — the invariant R2-04 asked for. A mismatch is a mismatch in
either direction, so perturbing the side that *can* be perturbed tests the same
comparison.
-/

namespace LLZK.Test.Constraints

open LLZK.Examples LLZK.ConstraintSet

abbrev Bab := F pBabybear

private def mulSrc : Source Bab := Compilable.source multiply
private def decSrc : Source Bab := Compilable.source decompose
private def addSrc : Source Bab :=
  Compilable.source (Gadgets.Addition8FullCarry.circuit (p := pBabybear))

/-! ## The corpus agrees

Driven off `Corpus.corpus` rather than listing the circuits again, so a new
corpus entry is covered without touching this file. The count is pinned as well
as the verdict: an entry that quietly stopped carrying a Clean source would
otherwise drop out of the gate silently. -/

-- Every corpus circuit with a Clean source emits Clean's constraint system, and
-- computes its witnesses. Both halves, because both are preconditions of
-- emission (D018) and a corpus entry that dropped one would still compile.
#guard Corpus.corpus.all fun e => e.constraintsAgree ≠ some false
#guard Corpus.corpus.all fun e => e.witnessAgree ≠ some false
#guard (Corpus.corpus.filter (·.witnessAgree = some true)).size == 5

-- Five of the eleven corpus entries have a Clean source. The other six are the
-- registry conformance squares, built from a `Recognized` — see `registryEntry`.
#guard (Corpus.corpus.filter (·.constraintsAgree = some true)).size == 5
#guard (Corpus.corpus.filter (·.constraintsAgree = none)).size == 6

/-! ## The gate can go red -/

/-- Compile `built`, then compare the module against `reference`'s constraints. -/
private def cross (cfg : Config) (built reference : Source Bab) : Bool :=
  match compileSource cfg built with
  | .error _ => false
  | .ok m => agree cfg reference m

/-- Remove every assertion. -/
private def noAsserts (s : Source Bab) : Source Bab :=
  { s with operations := s.operations.filter fun | .assert _ => false | _ => true }

/-- Remove every lookup. -/
private def noLookups (s : Source Bab) : Source Bab :=
  { s with operations := s.operations.filter fun | .lookup _ => false | _ => true }

/-- Emit every assertion twice. -/
private def dupAsserts (s : Source Bab) : Source Bab :=
  { s with operations := s.operations.flatMap fun | .assert e => [.assert e, .assert e]
                                                  | o => [o] }

/-- Add one to the leftmost constant of an expression. -/
private def bumpFirst : Expression Bab → Option (Expression Bab)
  | .const c => some (.const (c + 1))
  | .var _ => none
  | .add a b => match bumpFirst a with
    | some a' => some (.add a' b)
    | none => (bumpFirst b).map (.add a)
  | .mul a b => match bumpFirst a with
    | some a' => some (.mul a' b)
    | none => (bumpFirst b).map (.mul a)

/-- Perturb one coefficient in every assertion. -/
private def bumped (s : Source Bab) : Source Bab :=
  { s with operations := s.operations.map fun
      | .assert e => .assert ((bumpFirst e).getD e)
      | o => o }

-- The baselines, restated here so that a red control below cannot be explained
-- by the comparison being red for everything.
#guard cross babybear mulSrc mulSrc
#guard cross withBytes addSrc addSrc

-- A module compared against a different circuit's constraints.
#guard !cross babybear mulSrc decSrc

-- Missing constraints — the empty-`@constrain` failure mode.
#guard !cross babybear mulSrc (noAsserts mulSrc)
#guard !cross withBytes addSrc (noAsserts addSrc)

-- A wrong coefficient.
#guard !cross babybear mulSrc (bumped mulSrc)
#guard !cross withBytes addSrc (bumped addSrc)

-- A constraint counted twice: the comparison is by multiset, not by set.
#guard !cross babybear mulSrc (dupAsserts mulSrc)
#guard !cross withBytes addSrc (dupAsserts addSrc)

-- A missing lookup.
#guard !cross withBytes addSrc (noLookups addSrc)

-- A lookup against the wrong table: the comparison is on the name as well as the
-- queried polynomial, so a `constrain.in` pointed at a different global is red.
private def renameTable (s : Source Bab) : Source Bab :=
  { s with operations := s.operations.map fun
      | .lookup l => .lookup { l with table := { l.table with name := "Other" } }
      | o => o }
#guard !cross withBytes addSrc (renameTable addSrc)

/-! ### The two R4 named as residual risks, and which are real

R4's reviewers listed four risks inside G9. Two are covered by other gates and
two were genuine; the genuine ones are pinned here. -/

/-- The emitted `@constrain` reads a member `@compute` did not write to. Caught,
because the constraint's polynomial then names a different cell than Clean's. -/
private def felt : Ty := .felt "babybear"

private def crossedWires : Except Diagnostic (Option StructDef) :=
  Builder.component (ε := Diagnostic)
    #[{ name := "w0", ty := felt, visibility := .signal },
      { name := "w1", ty := felt, visibility := .signal },
      { name := "out0", ty := felt, visibility := .pub }]
    #[{ ty := felt, argName := "arg0" }]
    (fun self args => do
      let some x := args[0]? | pure ()
      Builder.writeMember self "w0" x felt
      Builder.writeMember self "w1" x felt
      Builder.writeMember self "out0" x felt)
    (fun self _ => do
      let w1 ← Builder.readMember self "w1" felt
      let o ← Builder.readMember self "out0" felt
      Builder.constrainEq o w1 felt)

/-- The circuit that module claims to be: two cells, `out0` equal to cell 0. -/
private def twoCellSrc : Source Bab :=
  { inputSize := 1
    operations := [.witness 2 (.ir [] (.lit #v[.expr (.var ⟨0⟩), .expr (.var ⟨0⟩)]))]
    outputs := #[.var ⟨1⟩] }

#guard match crossedWires.toOption.getD none with
  | some root => !(agree (F := Bab) babybear twoCellSrc { globals := #[], root })
  | none => false

-- The lookup table's *contents*. Before this the comparison recorded which table
-- each `constrain.in` names and never what the table holds, so a `@Bytes` global
-- with one row instead of 256 passed (R4).
private def oneRowBytes : Config :=
  .unsafeWithTables .babybear #[{ name := "Bytes", arity := 1, rows := #[#[0]] }]

#guard cross withBytes addSrc addSrc
#guard match compileSource withBytes addSrc with
  | .ok m => !(agree oneRowBytes addSrc m)
  | .error _ => false

/-! ### R5's X1: what an uncertified table actually costs

The control above compares a module built with one config against a
`ConstraintSet` built from another, and R5 was right that production never
produces that pairing — so it never exercised the attack, which is to compile
*with* the bad config. These do.

`fatBytes` is R5's witness: 512 rows where Clean's `ByteTable` has 256. -/

private def fatBytes : Config :=
  .unsafeWithTables .babybear #[{ name := "Bytes", arity := 1, rows := (Array.range 512).map (#[·]) }]

-- Compiling *with* it still succeeds, and `agree` still holds, because both
-- sides read the same `cfg.tables`. That is the tautology R5 identified; pinning
-- it stops the project claiming otherwise.
#guard match compileSource fatBytes addSrc with
  | .ok m => agree fatBytes addSrc m
  | .error _ => false

-- And the module it produces really is weaker: the emitted `@Bytes` holds 300,
-- which `Gadgets.ByteTable` does not contain. This is the soundness cost of
-- `unsafeWithTables`, stated as a fact rather than left to a docstring.
#guard match compileSource fatBytes addSrc with
  | .ok m => (m.globals.find? (·.name == "Bytes")).any (·.values.contains 300)
  | .error _ => false

-- What changed is that this can no longer be written by accident. The only
-- public way to put tables in a `Config` is `unsafeWithTables`, named so that
-- `scripts/llzk/check-unsafe-config.sh` can forbid it outside `Test/`, and
-- `Config.ofCertified` — which cannot express `fatBytes`, because
-- `ExportTable.Certifies` is false for it and there is no proof to supply.

/-! ## Canonicity

Not needed for soundness — `Poly.lean` says why — but worth pinning, because it
is what stops the gate producing *spurious* mismatches. The normal form absorbs
commutativity, associativity, distributivity and cancellation, so two
constraints that are equal as polynomials compare equal however they were
written. A6 reorders constraints; this covers reordering *inside* one. -/

private def px : Expression Bab := .var ⟨0⟩
private def py : Expression Bab := .var ⟨1⟩
private def pz : Expression Bab := .var ⟨2⟩

#guard Expression.toPoly (.mul px py) == Expression.toPoly (.mul py px)
#guard Expression.toPoly (.add px py) == Expression.toPoly (.add py px)
#guard Expression.toPoly (.mul px (.mul py pz)) == Expression.toPoly (.mul (.mul px py) pz)
#guard Expression.toPoly (.mul (.add px py) pz)
         == Expression.toPoly (.add (.mul px pz) (.mul py pz))
#guard Expression.toPoly (.add px (.mul (.const (-1)) px)) == ([] : Poly Bab)

-- And distinct polynomials stay distinct, or the four guards above would be
-- satisfied by a normal form that collapses everything.
#guard !(Expression.toPoly (.mul px py) == Expression.toPoly (.mul px pz))
#guard !(Expression.toPoly (.const 7) == (Expression.toPoly (.const 8) : Poly Bab))

/-! ## The shape the comparison found

Pinned so that a change in how many constraints a circuit has is a reviewed diff
rather than a silent one. `Addition8FullCarry` has four equalities — the boolean
constraint on the carry, the linear byte relation, and one per output — and one
lookup, which is exactly what the gadget writes. -/

private def shape (cfg : Config) (src : Source Bab) : Option (Nat × Nat) :=
  match compileSource cfg src with
  | .error _ => none
  | .ok m => (ofModule (F := Bab) m).map fun c => (c.eqs.length, c.lookups.length)

#guard shape babybear mulSrc == some (2, 0)
#guard shape babybear decSrc == some (2, 0)
#guard shape babybear (Compilable.source passthrough) == some (1, 0)
#guard shape babybear (Compilable.source constOut) == some (1, 0)
#guard shape withBytes addSrc == some (4, 1)

end LLZK.Test.Constraints
