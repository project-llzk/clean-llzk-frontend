import Clean.Backend.LLZK.WitnessCheck
import Clean.Backend.LLZK.Corpus
import Clean.Backend.LLZK.Examples

/-!
# Gate G9, witness side: the emitted `@compute` against Clean's witness programs

The companion to `Test/Constraints.lean`. Same standard: the gate is only worth
anything if it can go red, so every way the emitter could get `@compute` wrong is
perturbed here and pinned red.

The perturbations are on the *Clean* side because `Func` has a private
constructor and a module cannot be malformed by hand — the invariant R2-04 asked
for. A mismatch is a mismatch in either direction.

| Perturbation | The emitter bug it stands for |
|---|---|
| `x*x` compiled, compared against `x+x` | a wrong operation in a lowered witness |
| `x % 256` compiled, compared against `x % 128` | a wrong divisor — the literal D011 checks |
| `x % 256` compared against `x / 256` | `umod` emitted where `uintdiv` belongs |
| two cells, compared against the same two swapped | cells emitted in the wrong order |
| an output that is a cell, compared against a constant | a wrong `@out{j}` |
| one circuit's module against another's programs | the comparison being vacuous |

Cell order matters here and does not on the constraint side: cell `k` *is*
circuit variable `inputSize + k`, so a permutation is a different circuit, while
constraints are a conjunction.
-/

namespace LLZK.Test.WitnessCheck

open LLZK.Examples

abbrev Bab := F pBabybear

private def source (inputSize : Nat) (operations : List (FlatOperation Bab))
    (outputs : Array (Expression Bab) := #[]) : Source Bab :=
  { inputSize, operations, outputs }

/-- Compile `built`, then compare its `@compute` against `reference`'s witness
programs. -/
private def cross (cfg : Config) (built reference : Source Bab) : Bool :=
  match compileSource cfg built with
  | .error _ => false
  | .ok m => WitnessSet.agree reference m

/-! ## The corpus agrees -/

private def mulSrc : Source Bab := Compilable.source multiply
private def decSrc : Source Bab := Compilable.source decompose
private def addSrc : Source Bab :=
  Compilable.source (Gadgets.Addition8FullCarry.circuit (p := pBabybear))

#guard cross babybear mulSrc mulSrc
#guard cross babybear decSrc decSrc
#guard cross babybear (Compilable.source passthrough) (Compilable.source passthrough)
#guard cross babybear (Compilable.source constOut) (Compilable.source constOut)
#guard cross withBytes addSrc addSrc

-- The shapes, pinned so that a change in how many cells or outputs a circuit has
-- is a reviewed diff. `Addition8FullCarry` witnesses the low byte and the carry,
-- and returns both.
private def shape (src : Source Bab) : Option (Nat × Nat) :=
  (WitnessSet.ofSource src).map fun s => (s.cells.length, s.outputs.length)

#guard shape mulSrc == some (1, 1)
#guard shape decSrc == some (2, 2)
#guard shape addSrc == some (2, 2)
#guard shape (Compilable.source passthrough) == some (0, 1)
#guard shape (Compilable.source constOut) == some (0, 1)

/-! ## The gate can go red -/

private def wit (e : Witgen.FExpr Bab) : FlatOperation Bab :=
  .witness 1 (.ir [] (.lit #v[e]))

private def x : Witgen.FExpr Bab := .expr (.var ⟨0⟩)

private def sq : Source Bab := source 1 [wit (.mul x x)] #[.var ⟨1⟩]
private def dbl : Source Bab := source 1 [wit (.add x x)] #[.var ⟨1⟩]
private def mod256 : Source Bab := source 1 [wit (.ofNat (.mod (.val x) (.const 256)))] #[.var ⟨1⟩]
private def mod128 : Source Bab := source 1 [wit (.ofNat (.mod (.val x) (.const 128)))] #[.var ⟨1⟩]
private def div256 : Source Bab := source 1 [wit (.ofNat (.div (.val x) (.const 256)))] #[.var ⟨1⟩]
private def twoCells : Source Bab :=
  source 1 [.witness 2 (.ir [] (.lit #v[.mul x x, .add x x]))] #[.var ⟨1⟩, .var ⟨2⟩]
private def twoCellsSwapped : Source Bab :=
  source 1 [.witness 2 (.ir [] (.lit #v[.add x x, .mul x x]))] #[.var ⟨1⟩, .var ⟨2⟩]
private def outConst : Source Bab := source 1 [wit (.mul x x)] #[.const 7]

-- Baselines, so that a red below cannot be explained by everything being red.
#guard cross babybear sq sq
#guard cross babybear mod256 mod256
#guard cross babybear twoCells twoCells

-- A wrong operation.
#guard !cross babybear sq dbl
-- A wrong divisor: the literal D011's side conditions are checked against.
#guard !cross babybear mod256 mod128
-- `umod` where `uintdiv` belongs.
#guard !cross babybear mod256 div256
-- Cells in the wrong order.
#guard !cross babybear twoCells twoCellsSwapped
-- A wrong output.
#guard !cross babybear sq outConst
-- A different circuit entirely.
#guard !cross babybear mulSrc decSrc
#guard !cross babybear decSrc mulSrc

/-! ## The reader is fail-closed on `@constrain`'s statement forms

`WitnessSet.ofModule` models `@compute` only. Feeding it a module is safe
because `Module` exposes both functions, but the reader must refuse anything
carrying a constraint — otherwise "it read the module" would not mean "it read
the compute function". Nothing in the corpus reaches those branches, so this
pins the one property that stands in for them: the reader accepts exactly the
modules whose `@compute` is in the modelled subset, and every corpus module is. -/

#guard (Corpus.corpus.filterMap (fun e => e.module.toOption)).all
  fun m => (WitnessSet.ofModule m).isSome

end LLZK.Test.WitnessCheck
