import Clean.Backend.LLZK.WitnessCheck
import Clean.Backend.LLZK.Corpus
import Clean.Backend.LLZK.Examples
import Clean.Gadgets.Xor.Xor32

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

/-! ## D033's width boundary

These guards use a payload type with no field instance so they test the total
syntax analysis itself, not a registry field or the emitter around it. A `.val`
leaf is exact at the `2^64` boundary and refused immediately above it. -/

private def syntheticVal : Witgen.U64Expr Nat := .val (.const 0)

#guard U64Expr.upperBound (2 ^ 64) syntheticVal == some (2 ^ 64)
#guard (U64Expr.upperBound (2 ^ 64 + 1) syntheticVal).isNone

/-! ## S29's exact modulo and common bitwise ceilings

The inputs below are written as their largest possible value, so their
exclusive source bound is one larger. Modulo takes the minimum of that bound and
the literal divisor. XOR and OR take the least power of two at least as large as
the larger operand bound. The `257` row distinguishes a true ceiling from the
old blanket `2^64`, and the last two rows pin the u64 boundary itself. -/

private def modBound (n d : UInt64) : Option Nat :=
  U64Expr.upperBound (2 ^ 64) (.mod (.const n) (.const d) : Witgen.U64Expr Nat)

private def xorBound (a b : UInt64) : Option Nat :=
  U64Expr.upperBound (2 ^ 64) (.lxor (.const a) (.const b) : Witgen.U64Expr Nat)

private def orBound (a b : UInt64) : Option Nat :=
  U64Expr.upperBound (2 ^ 64) (.lor (.const a) (.const b) : Witgen.U64Expr Nat)

#guard modBound 0 256 == some 1
#guard modBound 1 256 == some 2
#guard modBound 254 256 == some 255
#guard modBound 255 256 == some 256
#guard modBound 256 1024 == some 257
#guard modBound (2 ^ 63 - 1) (2 ^ 64 - 1) == some (2 ^ 63)
#guard modBound (2 ^ 64 - 1) 1 == some 1
#guard modBound (2 ^ 64 - 1) 2 == some 2
#guard modBound (2 ^ 64 - 1) 255 == some 255
#guard modBound (2 ^ 64 - 1) 256 == some 256
#guard modBound (2 ^ 64 - 1) 257 == some 257
#guard modBound (2 ^ 64 - 1) (2 ^ 63) == some (2 ^ 63)
#guard U64Expr.upperBound (2 ^ 64) (.const (2 ^ 64 - 1) : Witgen.U64Expr Nat)
  == some (2 ^ 64)

#guard xorBound 0 0 == some 1
#guard xorBound 1 1 == some 2
#guard xorBound 254 254 == some 256
#guard xorBound 255 255 == some 256
#guard xorBound 256 256 == some 512
#guard xorBound (2 ^ 63 - 1) (2 ^ 63 - 1) == some (2 ^ 63)
#guard xorBound (2 ^ 64 - 1) (2 ^ 64 - 1) == some (2 ^ 64)
#guard xorBound 0 256 == some 512
#guard xorBound 256 0 == some 512

#guard orBound 0 0 == some 1
#guard orBound 1 1 == some 2
#guard orBound 254 254 == some 256
#guard orBound 255 255 == some 256
#guard orBound 256 256 == some 512
#guard orBound (2 ^ 63 - 1) (2 ^ 63 - 1) == some (2 ^ 63)
#guard orBound (2 ^ 64 - 1) (2 ^ 64 - 1) == some (2 ^ 64)
#guard orBound 0 256 == some 512
#guard orBound 256 0 == some 512

-- `upperBound` computes the syntactic ceiling; the recognizer's separate root
-- field guard rejects this one because 2^31 is above Babybear.
#guard U64Expr.upperBound pBabybear (.lxor syntheticVal (.const 1)) == some (2 ^ 31)
#guard U64Expr.upperBound pBabybear (.lor syntheticVal (.const 1)) == some (2 ^ 31)

private def syntaxX : Witgen.FExpr Bab := .expr (.var ⟨0⟩)
private def feltReducingChild : Witgen.U64Expr Bab := .add (.val syntaxX) (.const 1)
private def feltReducingMod : Witgen.U64Expr Bab := .mod feltReducingChild (.const 256)
private def u64WrappingChild : Witgen.U64Expr Bab :=
  .add (.const (2 ^ 64 - 1)) (.const 1)
private def u64WrappingMod : Witgen.U64Expr Bab := .mod u64WrappingChild (.const 256)
private def idxMod : Witgen.U64Expr Bab := .mod .idx (.const 256)
private def localMod : Witgen.U64Expr Bab := .mod (.localVar 0) (.const 256)
private def dynamicMod : Witgen.U64Expr Bab := .mod (.val syntaxX) (.val syntaxX)
private def zeroMod : Witgen.U64Expr Bab := .mod (.val syntaxX) (.const 0)
private def primeMod : Witgen.U64Expr Bab :=
  .mod (.val syntaxX) (.const (UInt64.ofNat pBabybear))
private def narrowSyntax256 : Witgen.U64Expr Bab := .mod (.val syntaxX) (.const 256)

#guard U64Expr.upperBound pBabybear feltReducingChild == some (pBabybear + 2)
#guard U64Expr.upperBound pBabybear feltReducingMod == some 256
#guard pBabybear % 256 == 1
#guard (WExpr.ofWitgen (.ofU64 feltReducingMod)).isNone
#guard (U64Expr.upperBound pBabybear u64WrappingChild).isNone
#guard (U64Expr.upperBound pBabybear u64WrappingMod).isNone
#guard (WExpr.ofWitgen (.ofU64 u64WrappingMod)).isNone
#guard (U64Expr.upperBound pBabybear idxMod).isNone
#guard (U64Expr.upperBound pBabybear localMod).isNone
#guard (U64Expr.upperBound pBabybear dynamicMod).isNone
#guard (U64Expr.upperBound pBabybear zeroMod).isNone
#guard U64Expr.upperBound pBabybear primeMod == some pBabybear
#guard (WExpr.ofWitgen (.ofU64 primeMod)).isNone
#guard (U64Expr.upperBound FieldSpec.bn254.prime
  (.mod (.val syntaxX) (.const 3))).isNone
#guard (U64Expr.upperBound FieldSpec.bn254.prime
  (.mod (.val syntaxX) (.const 256))).isNone
#guard U64Expr.upperBound pBabybear (.lxor narrowSyntax256 narrowSyntax256) == some 256
#guard U64Expr.upperBound pBabybear (.lor narrowSyntax256 narrowSyntax256) == some 256

private def source (inputSize : Nat) (operations : List (FlatOperation Bab))
    (outputs : Array (Expression Bab) := #[]) : Source Bab :=
  { inputSize, operations, outputs }

/-- Compile `built`, then compare its `@compute` against `reference`'s witness
programs. -/
private def cross (cfg : CertifiedConfig Bab) (built reference : Source Bab) : Bool :=
  match compileSource cfg.toConfig built with
  | .error _ => false
  | .ok m => WitnessSet.agree (Ty.felt cfg.field.name) reference m

/-! ## The corpus agrees -/

private def mulSrc : Source Bab := Compilable.source multiply
private def decSrc : Source Bab := Compilable.source decompose
private def lowByteSrc : Source Bab := Compilable.source lowByte
private def bits8Src : Source Bab := Compilable.source bits8
private def addSrc : Source Bab :=
  Compilable.source (Gadgets.Addition8FullCarry.circuit (p := pBabybear))
private def xorSrc : Source Bab :=
  Compilable.source (Gadgets.Xor32.circuit (p := pBabybear))

#guard cross babybear mulSrc mulSrc
#guard cross babybear decSrc decSrc
#guard cross babybear lowByteSrc lowByteSrc
#guard cross babybear bits8Src bits8Src
#guard cross babybear (Compilable.source passthrough) (Compilable.source passthrough)
#guard cross babybear (Compilable.source constOut) (Compilable.source constOut)
#guard cross withBytes addSrc addSrc
#guard cross withBytesAndXor xorSrc xorSrc

-- The shapes, pinned so that a change in how many cells or outputs a circuit has
-- is a reviewed diff. `Addition8FullCarry` witnesses the low byte and the carry,
-- and returns both.
private def shape (src : Source Bab) : Option (Nat × Nat) :=
  (WitnessSet.ofSource src).map fun s => (s.cells.length, s.outputs.length)

#guard shape mulSrc == some (1, 1)
#guard shape decSrc == some (2, 2)
#guard shape lowByteSrc == some (1, 1)
#guard shape bits8Src == some (8, 8)
#guard shape addSrc == some (2, 2)
#guard shape xorSrc == some (4, 4)
#guard shape (Compilable.source passthrough) == some (0, 1)
#guard shape (Compilable.source constOut) == some (0, 1)

/-! ### Xor32's exact source, recognized, typed-module, and reader shapes -/

private def xorCells : List WExpr :=
  [ .u64Bin .bitXor (.umod (.cell 0) 256) (.umod (.cell 4) 256)
  , .u64Bin .bitXor (.umod (.cell 1) 256) (.umod (.cell 5) 256)
  , .u64Bin .bitXor (.umod (.cell 2) 256) (.umod (.cell 6) 256)
  , .u64Bin .bitXor (.umod (.cell 3) 256) (.umod (.cell 7) 256) ]

private def xorWitnessSet : WitnessSet :=
  { inputs := 8
    cells := xorCells
    outputs := [.cell 8, .cell 9, .cell 10, .cell 11] }

#guard WitnessSet.ofSource xorSrc == some xorWitnessSet

private def xorSourceShape : Bool :=
  xorSrc.inputSize == 8 && xorSrc.outputs.size == 4 &&
    match xorSrc.operations with
    | [.witness 4 _, .lookup _, .lookup _, .lookup _, .lookup _] => true
    | _ => false

#guard xorSourceShape

private def xorFieldExprs : Array FieldExpr :=
  #[ .u64Bin .bitXor (.umod (.var 0) 256) (.umod (.var 4) 256)
   , .u64Bin .bitXor (.umod (.var 1) 256) (.umod (.var 5) 256)
   , .u64Bin .bitXor (.umod (.var 2) 256) (.umod (.var 6) 256)
   , .u64Bin .bitXor (.umod (.var 3) 256) (.umod (.var 7) 256) ]

private def xorLookupRows : Array (Array FieldExpr) :=
  #[ #[.var 0, .var 4, .var 8]
   , #[.var 1, .var 5, .var 9]
   , #[.var 2, .var 6, .var 10]
   , #[.var 3, .var 7, .var 11] ]

private def xorRecognizedExact : Bool :=
  match recognize withBytesAndXor.toConfig xorSrc with
  | .error _ => false
  | .ok recognized =>
      recognized.inputSize == 8 && recognized.witnesses == xorFieldExprs &&
      recognized.asserts.isEmpty &&
      recognized.lookups.map (fun lookup =>
        (lookup.tableName, lookup.tableRows, lookup.tableArity, lookup.entry)) ==
          xorLookupRows.map (fun row => ("ByteXor", 65536, 3, row)) &&
      recognized.tables.map (fun table => (table.name, table.arity, table.rows)) ==
        #[("ByteXor", 3, byteXorRows)] &&
      recognized.outputs == #[.var 8, .var 9, .var 10, .var 11]

#guard xorRecognizedExact

private def xorModuleExact : Bool :=
  match compile withBytesAndXor (Gadgets.Xor32.circuit (p := pBabybear)) with
  | .error _ => false
  | .ok m =>
      let inputParams := (Array.range 8).map fun i =>
        (Ty.felt "babybear", some s!"arg{i}")
      m.globals.map (fun table => (table.name, table.elemTy, table.arity, table.rows)) ==
          #[("ByteXor", Ty.felt "babybear", 3, byteXorRows)] &&
        m.root.compute.params.map (fun param => (param.ty, param.argName)) == inputParams &&
        m.root.constrain.params.map (fun param => (param.ty, param.argName)) ==
          #[(rootTy, none)] ++ inputParams &&
        m.root.members.map (fun member => (member.name, member.ty, member.visibility)) ==
          #[ ("w0", Ty.felt "babybear", .signal)
           , ("w1", Ty.felt "babybear", .signal)
           , ("w2", Ty.felt "babybear", .signal)
           , ("w3", Ty.felt "babybear", .signal)
           , ("out0", Ty.felt "babybear", .pub)
           , ("out1", Ty.felt "babybear", .pub)
           , ("out2", Ty.felt "babybear", .pub)
           , ("out3", Ty.felt "babybear", .pub) ] &&
        WitnessSet.ofModule (Ty.felt "babybear") m == some xorWitnessSet

#guard xorModuleExact

/-! Xor-specific G9 mutations. Each mutant reads successfully against itself
before the normal compiled module is required to reject it as a reference. -/

private def sourceF (index : Nat) : Witgen.FExpr Bab := .expr (.var ⟨index⟩)

private def narrow (index : Nat) (divisor : UInt64 := 256) : Witgen.U64Expr Bab :=
  .mod (.val (sourceF index)) (.const divisor)

private def xorCell (x y : Nat) : Witgen.FExpr Bab :=
  .ofU64 (.lxor (narrow x) (narrow y))

private def xorProgramSource (cells : Vector (Witgen.FExpr Bab) 4) : Source Bab :=
  { xorSrc with operations := xorSrc.operations.map fun
      | .witness _ _ => .witness 4 (.ir [] (.lit cells))
      | operation => operation }

private def wrongDivisorXor : Source Bab := xorProgramSource
  #v[.ofU64 (.lxor (narrow 0 128) (narrow 4)), xorCell 1 5, xorCell 2 6, xorCell 3 7]

private def wrongOperatorXor : Source Bab := xorProgramSource
  #v[xorCell 0 4, .ofU64 (.lor (narrow 1) (narrow 5)), xorCell 2 6, xorCell 3 7]

private def wrongOperandXor : Source Bab := xorProgramSource
  #v[xorCell 0 4, xorCell 1 5, xorCell 2 7, xorCell 3 7]

private def permutedXorOutputs : Source Bab :=
  { xorSrc with outputs := #[.var ⟨9⟩, .var ⟨8⟩, .var ⟨10⟩, .var ⟨11⟩] }

#guard cross withBytesAndXor wrongDivisorXor wrongDivisorXor
#guard cross withBytesAndXor wrongOperatorXor wrongOperatorXor
#guard cross withBytesAndXor wrongOperandXor wrongOperandXor
#guard cross withBytesAndXor permutedXorOutputs permutedXorOutputs
#guard !cross withBytesAndXor xorSrc wrongDivisorXor
#guard !cross withBytesAndXor xorSrc wrongOperatorXor
#guard !cross withBytesAndXor xorSrc wrongOperandXor
#guard !cross withBytesAndXor xorSrc permutedXorOutputs

/-! ## The gate can go red -/

private def wit (e : Witgen.FExpr Bab) : FlatOperation Bab :=
  .witness 1 (.ir [] (.lit #v[e]))

private def x : Witgen.FExpr Bab := .expr (.var ⟨0⟩)
private def y : Witgen.FExpr Bab := .expr (.var ⟨1⟩)

private def sq : Source Bab := source 1 [wit (.mul x x)] #[.var ⟨1⟩]
private def dbl : Source Bab := source 1 [wit (.add x x)] #[.var ⟨1⟩]
private def mod256 : Source Bab := source 1 [wit (.ofU64 (.mod (.val x) (.const 256)))] #[.var ⟨1⟩]
private def mod128 : Source Bab := source 1 [wit (.ofU64 (.mod (.val x) (.const 128)))] #[.var ⟨1⟩]
private def div256 : Source Bab := source 1 [wit (.ofU64 (.div (.val x) (.const 256)))] #[.var ⟨1⟩]
private def and255 : Source Bab :=
  source 1 [wit (.ofU64 (.land (.val x) (.const 255)))] #[.var ⟨1⟩]
private def and127 : Source Bab :=
  source 1 [wit (.ofU64 (.land (.val x) (.const 127)))] #[.var ⟨1⟩]
private def narrowAt (e : Witgen.FExpr Bab) (d : UInt64) : Witgen.U64Expr Bab :=
  .mod (.val e) (.const d)
private def xorXY : Source Bab :=
  source 2 [wit (.ofU64 (.lxor (narrowAt x 256) (narrowAt y 256)))] #[.var ⟨2⟩]
private def orXY : Source Bab :=
  source 2 [wit (.ofU64 (.lor (narrowAt x 256) (narrowAt y 256)))] #[.var ⟨2⟩]
private def xorXX : Source Bab :=
  source 2 [wit (.ofU64 (.lxor (narrowAt x 256) (narrowAt x 256)))] #[.var ⟨2⟩]
private def xorOne128 : Source Bab :=
  source 2 [wit (.ofU64 (.lxor (narrowAt x 256) (narrowAt y 128)))] #[.var ⟨2⟩]
private def twoCells : Source Bab :=
  source 1 [.witness 2 (.ir [] (.lit #v[.mul x x, .add x x]))] #[.var ⟨1⟩, .var ⟨2⟩]
private def twoCellsSwapped : Source Bab :=
  source 1 [.witness 2 (.ir [] (.lit #v[.add x x, .mul x x]))] #[.var ⟨1⟩, .var ⟨2⟩]
private def outConst : Source Bab := source 1 [wit (.mul x x)] #[.const 7]

-- Baselines, so that a red below cannot be explained by everything being red.
#guard cross babybear sq sq
#guard cross babybear dbl dbl
#guard cross babybear mod256 mod256
#guard cross babybear mod128 mod128
#guard cross babybear div256 div256
#guard cross babybear and255 and255
#guard cross babybear and127 and127
#guard cross babybear xorXY xorXY
#guard cross babybear orXY orXY
#guard cross babybear xorXX xorXX
#guard cross babybear xorOne128 xorOne128
#guard cross babybear twoCells twoCells
#guard cross babybear twoCellsSwapped twoCellsSwapped
#guard cross babybear outConst outConst

-- A wrong operation.
#guard !cross babybear sq dbl
-- A wrong divisor: the literal D011's side conditions are checked against.
#guard !cross babybear mod256 mod128
-- `umod` where `uintdiv` belongs.
#guard !cross babybear mod256 div256
-- A wrong bitwise operand.
#guard !cross babybear and255 and127
-- XOR and OR are distinct emitted operations.
#guard !cross babybear xorXY orXY
-- A wrong XOR operand.
#guard !cross babybear xorXY xorXX
-- Narrowing by the wrong byte divisor.
#guard !cross babybear xorXY xorOne128
-- Cells in the wrong order.
#guard !cross babybear twoCells twoCellsSwapped
-- A wrong output.
#guard !cross babybear sq outConst
-- A different circuit entirely.
#guard !cross babybear mulSrc decSrc
#guard !cross babybear decSrc mulSrc

/-! ## Copies collapse, and only copies

A witness cell whose program is a bare variable is a copy: `FieldExpr.lower`
emits nothing and `@compute` writes the value that already stood for the
original. So `witness x; return x` and `witness x; return that cell` emit
*byte-identical* modules, and a reader of the module alone cannot distinguish
them — which means neither side of the comparison may. Both canonicalise a copy
to the variable it copies.

R5c found this by having a correct module for `copyCell`, a proved
`FormalCircuit`, refused with "this is a defect in the backend, please report
it". The last three guards are the ones that keep the fix from being a blanket
weakening: a computed cell still has its own identity. -/

private def cellOfInput : Witgen.FExpr Bab := .expr (.var ⟨1⟩)

private def copyOutInput : Source Bab := source 1 [wit x] #[.var ⟨0⟩]
private def copyOutCell : Source Bab := source 1 [wit x] #[.var ⟨1⟩]
private def copyOfCopy : Source Bab :=
  source 1 [wit x, wit cellOfInput] #[.var ⟨2⟩, .var ⟨0⟩]
/-- `x + 0` is *computed*, not copied: it gets its own SSA statement. -/
private def notACopy : Source Bab := source 1 [wit (.add x (.const 0))] #[.var ⟨0⟩]

#guard cross babybear copyOutInput copyOutInput
#guard cross babybear copyOutCell copyOutCell
#guard cross babybear copyOfCopy copyOfCopy
#guard cross babybear notACopy notACopy
#guard cross babybear (Compilable.source copyCell) (Compilable.source copyCell)

-- The same module, so necessarily the same reading, in both directions.
#guard cross babybear copyOutInput copyOutCell
#guard cross babybear copyOutCell copyOutInput

-- What the two sides actually read. A copy resolves to the variable it copies;
-- a computed cell does not, and its own index is still a distinct name.
#guard (WitnessSet.ofSource copyOutCell).map (·.outputs) == some [.cell 0]
#guard (WitnessSet.ofSource copyOfCopy).map (·.cells) == some [.cell 0, .cell 0]
#guard (WitnessSet.ofSource notACopy).map (·.cells)
  == some [.add (.cell 0) (.const 0)]
#guard (WitnessSet.ofSource notACopy).map (·.outputs) == some [.cell 0]

-- Collapsing copies must not collapse anything else: a two-cell circuit whose
-- cells are genuinely different still refuses the swapped reading.
#guard !cross babybear notACopy copyOutInput
#guard !cross babybear copyOutInput notACopy

/-! ## The reader is fail-closed on `@constrain`'s statement forms

`WitnessSet.ofModule` models `@compute` only. Feeding it a module is safe
because `Module` exposes both functions, but the reader must refuse anything
carrying a constraint — otherwise "it read the module" would not mean "it read
the compute function". Nothing in the corpus reaches those branches, so this
pins the one property that stands in for them: the reader accepts exactly the
modules whose `@compute` is in the modelled subset, and every corpus module is. -/

-- Each against *its own* field: the six `Square_*` entries are in six different
-- ones, and since A4 the reader checks that (`GAPS.md` §6).
#guard Corpus.corpus.all fun e => match e.module.toOption with
  | some m => (WitnessSet.ofModule (Ty.felt e.field.name) m).isSome
  | none => true

/-! ## The refusal is reachable, and reached

`D018`'s weakness is that a correct emitter never triggers the refusal, so the
error branch would otherwise be dead code and "the emitter refuses a wrong
module" an untested claim about the one path that matters. `verify` takes the
module as an argument, so a test can hand it one circuit's module and another
circuit's source. -/

private def moduleOf (cfg : CertifiedConfig Bab) (src : Source Bab) : Option Module :=
  (compileSource cfg.toConfig src).toOption

-- Its own module is accepted…
#guard match moduleOf babybear mulSrc with
  | some m => (verify babybear mulSrc m).toOption.isSome
  | none => false

-- …and another circuit's is refused.
#guard match moduleOf babybear decSrc with
  | some m => (verify babybear mulSrc m).toOption.isNone
  | none => false

-- `verify` checks the constraint half first, so reaching the witness diagnostic
-- needs a module whose constraints are right and whose `@compute` is not. `sq`
-- and `dbl` are exactly that pair: neither constrains its cell, so both have the
-- constraint system `@out0 - v1` and differ only in what `@compute` writes.
--
-- Worth having for its own sake, not just to cover a branch: it is the case that
-- shows the two halves are independent, and that the witness half catches a
-- wrong `@compute` the constraint half cannot see.
#guard match moduleOf babybear dbl with
  | some m => ConstraintSet.agree babybear.toConfig sq m
      && !WitnessSet.agree (Ty.felt babybear.field.name) sq m
  | none => false

#guard match moduleOf babybear dbl with
  | some m => match verify babybear sq m with
    | .error ds => ds.map (·.context) == #["witness"]
    | .ok _ => false
  | none => false

-- And the constraint diagnostic, for a module that fails that half.
#guard match moduleOf babybear decSrc with
  | some m => match verify babybear mulSrc m with
    | .error ds => ds.map (·.context) == #["constraints"]
    | .ok _ => false
  | none => false

end LLZK.Test.WitnessCheck
