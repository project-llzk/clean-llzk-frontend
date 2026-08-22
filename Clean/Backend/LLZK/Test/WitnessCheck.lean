import Clean.Backend.LLZK.WitnessCheck
import Clean.Backend.LLZK.Corpus
import Clean.Backend.LLZK.Examples
import Clean.Gadgets.Xor.Xor32
import Clean.Gadgets.BLAKE3.BLAKE3G

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
private def blake3gSrc : Source Bab :=
  Compilable.source (Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear))

#guard cross babybear mulSrc mulSrc
#guard cross babybear decSrc decSrc
#guard cross babybear lowByteSrc lowByteSrc
#guard cross babybear bits8Src bits8Src
#guard cross babybear (Compilable.source passthrough) (Compilable.source passthrough)
#guard cross babybear (Compilable.source constOut) (Compilable.source constOut)
#guard cross withBytes addSrc addSrc
#guard cross withBytesAndXor xorSrc xorSrc
#guard cross withBytesAndXor blake3gSrc blake3gSrc

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
#guard shape blake3gSrc == some (96, 64)
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

/-! ### BLAKE3.G 0/1/2/3 exact source, recognized, module, and reader shapes -/

private def blake3gOutputs : Array (Expression Bab) :=
  #[ .var ⟨128⟩, .var ⟨130⟩, .var ⟨132⟩, .var ⟨134⟩
   , .var ⟨161⟩ + .var ⟨162⟩ * 2, .var ⟨163⟩ + .var ⟨164⟩ * 2
   , .var ⟨165⟩ + .var ⟨166⟩ * 2, .var ⟨167⟩ + .var ⟨160⟩ * 2
   , .var ⟨148⟩, .var ⟨150⟩, .var ⟨152⟩, .var ⟨154⟩
   , .var ⟨141⟩ + .var ⟨142⟩ * 256, .var ⟨143⟩ + .var ⟨144⟩ * 256
   , .var ⟨145⟩ + .var ⟨146⟩ * 256, .var ⟨147⟩ + .var ⟨140⟩ * 256 ] ++
    (Array.range 48).map fun i ↦ .var ⟨16 + i⟩

private def blake3gWitnessOutputs : List WExpr :=
  [ .cell 128, .cell 130, .cell 132, .cell 134
  , .add (.cell 161) (.mul (.cell 162) (.const 2))
  , .add (.cell 163) (.mul (.cell 164) (.const 2))
  , .add (.cell 165) (.mul (.cell 166) (.const 2))
  , .add (.cell 167) (.mul (.cell 160) (.const 2))
  , .cell 148, .cell 150, .cell 152, .cell 154
  , .add (.cell 141) (.mul (.cell 142) (.const 256))
  , .add (.cell 143) (.mul (.cell 144) (.const 256))
  , .add (.cell 145) (.mul (.cell 146) (.const 256))
  , .add (.cell 147) (.mul (.cell 140) (.const 256)) ] ++
    (List.range 48).map fun i ↦ .cell (16 + i)

private def blake3gLookupNames : Array String :=
  Array.replicate 8 "Bytes" ++ Array.replicate 4 "ByteXor" ++
  Array.replicate 12 "Bytes" ++ Array.replicate 4 "ByteXor" ++
  Array.replicate 16 "Bytes" ++ Array.replicate 4 "ByteXor" ++
  Array.replicate 12 "Bytes" ++ Array.replicate 4 "ByteXor" ++
  Array.replicate 8 "Bytes"

private def blake3gTopOperations : Operations Bab :=
  ((Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear)).main
    (varFromOffset Gadgets.BLAKE3.G.Inputs 0)).operations 72

private def blake3gChildWitnessLengths : List Nat :=
  blake3gTopOperations.filterMap fun
    | .subcircuit subcircuit => some subcircuit.localLength
    | _ => none

#guard blake3gTopOperations.length == 14
#guard blake3gChildWitnessLengths == [8, 8, 4, 8, 8, 4, 8, 8, 8, 4, 8, 8, 4, 8]

private def blake3gSourceExact : Bool :=
  let witnessOps := blake3gSrc.operations.filterMap fun
    | .witness m _ => some m
    | _ => none
  blake3gSrc.inputSize == 72 && blake3gSrc.operations.length == 220 &&
    witnessOps.length == 84 && witnessOps.foldl (init := 0) (fun n m ↦ n + m) == 96 &&
    (blake3gSrc.operations.filter fun | .assert _ => true | _ => false).length == 64 &&
    (blake3gSrc.operations.filter fun | .lookup _ => true | _ => false).length == 72 &&
    (blake3gSrc.operations.filter fun | .interact _ => true | _ => false).isEmpty &&
    blake3gSrc.outputs.map WExpr.ofExpression == blake3gWitnessOutputs.toArray

#guard blake3gSourceExact

private def blake3gWitnessReaderExact : Bool :=
  match WitnessSet.ofSource blake3gSrc with
  | none => false
  | some witnessSet =>
      witnessSet.inputs == 72 && witnessSet.cells.length == 96 &&
        witnessSet.outputs == blake3gWitnessOutputs

#guard blake3gWitnessReaderExact

private def blake3gRecognizedExact : Bool :=
  match recognize withBytesAndXor.toConfig blake3gSrc with
  | .error _ => false
  | .ok recognized =>
      recognized.inputSize == 72 && recognized.witnesses.size == 96 &&
        recognized.asserts.size == 64 && recognized.lookups.size == 72 &&
        recognized.lookups.map (fun lookup ↦ lookup.tableName) == blake3gLookupNames &&
        recognized.lookups.all fun lookup ↦
          if lookup.tableName == "Bytes" then
            lookup.tableRows == 256 && lookup.tableArity == 1 && lookup.entry.size == 1
          else
            lookup.tableName == "ByteXor" && lookup.tableRows == 65536 &&
              lookup.tableArity == 3 && lookup.entry.size == 3 &&
        recognized.tables.map (fun table ↦ (table.name, table.arity, table.rows)) ==
          #[("Bytes", 1, byteRows), ("ByteXor", 3, byteXorRows)] &&
        recognized.outputs == blake3gOutputs.map FieldExpr.ofExpression

#guard blake3gRecognizedExact

private def blake3gModuleExact : Bool :=
  match compile withBytesAndXor
    (Gadgets.BLAKE3.G.circuit 0 1 2 3 (p := pBabybear)) with
  | .error _ => false
  | .ok m =>
      let felt := Ty.felt "babybear"
      let inputParams := (Array.range 72).map fun i ↦ (felt, some s!"arg{i}")
      let expectedMembers :=
        (Array.range 96).map (fun i ↦ (s!"w{i}", felt, Visibility.signal)) ++
        (Array.range 64).map (fun i ↦ (s!"out{i}", felt, Visibility.pub))
      m.globals.map (fun table ↦ (table.name, table.elemTy, table.arity, table.rows)) ==
          #[("Bytes", felt, 1, byteRows), ("ByteXor", felt, 3, byteXorRows)] &&
        m.root.compute.name == "compute" && m.root.compute.body.size == 629 &&
        m.root.compute.params.map (fun param ↦ (param.ty, param.argName)) == inputParams &&
        m.root.constrain.name == "constrain" && m.root.constrain.body.size == 1027 &&
        m.root.constrain.params.map (fun param ↦ (param.ty, param.argName)) ==
          #[(rootTy, none)] ++ inputParams &&
        m.root.members.map (fun member ↦ (member.name, member.ty, member.visibility)) ==
          expectedMembers &&
        WitnessSet.ofModule felt m == WitnessSet.ofSource blake3gSrc

#guard blake3gModuleExact

private def blake3gWrongIndices : Source Bab :=
  Compilable.source (Gadgets.BLAKE3.G.circuit 0 1 2 4 (p := pBabybear))

private def blake3gPermutedOutputs : Source Bab :=
  match blake3gSrc.outputs[0]?, blake3gSrc.outputs[4]? with
  | some output0, some output4 =>
      { blake3gSrc with outputs :=
          (blake3gSrc.outputs.set! 0 output4).set! 4 output0 }
  | _, _ => blake3gSrc

private def replaceWitnessWithZeroAt : Nat → List (FlatOperation Bab) →
    List (FlatOperation Bab)
  | _, [] => []
  | 0, .witness 1 _ :: operations =>
      .witness 1 (.ir [] (.lit #v[.const 0])) :: operations
  | n + 1, .witness m program :: operations =>
      .witness m program :: replaceWitnessWithZeroAt n operations
  | n, operation :: operations => operation :: replaceWitnessWithZeroAt n operations

private def blake3gWrongWitness : Source Bab :=
  { blake3gSrc with operations := replaceWitnessWithZeroAt 0 blake3gSrc.operations }
private def blake3gWrongMiddleWitness : Source Bab :=
  { blake3gSrc with operations := replaceWitnessWithZeroAt 42 blake3gSrc.operations }
private def blake3gWrongLastWitness : Source Bab :=
  { blake3gSrc with operations := replaceWitnessWithZeroAt 83 blake3gSrc.operations }
private def blake3gWrongRotation16 : Source Bab :=
  { blake3gSrc with operations := replaceWitnessWithZeroAt 17 blake3gSrc.operations }
private def blake3gWrongRotation12 : Source Bab :=
  { blake3gSrc with operations := replaceWitnessWithZeroAt 34 blake3gSrc.operations }
private def blake3gWrongRotation8 : Source Bab :=
  { blake3gSrc with operations := replaceWitnessWithZeroAt 59 blake3gSrc.operations }
private def blake3gWrongRotation7 : Source Bab :=
  { blake3gSrc with operations := replaceWitnessWithZeroAt 76 blake3gSrc.operations }

#guard cross withBytesAndXor blake3gWrongIndices blake3gWrongIndices
#guard cross withBytesAndXor blake3gPermutedOutputs blake3gPermutedOutputs
#guard cross withBytesAndXor blake3gWrongWitness blake3gWrongWitness
#guard cross withBytesAndXor blake3gWrongMiddleWitness blake3gWrongMiddleWitness
#guard cross withBytesAndXor blake3gWrongLastWitness blake3gWrongLastWitness
#guard cross withBytesAndXor blake3gWrongRotation16 blake3gWrongRotation16
#guard cross withBytesAndXor blake3gWrongRotation12 blake3gWrongRotation12
#guard cross withBytesAndXor blake3gWrongRotation8 blake3gWrongRotation8
#guard cross withBytesAndXor blake3gWrongRotation7 blake3gWrongRotation7
#guard !cross withBytesAndXor blake3gSrc blake3gWrongIndices
#guard !cross withBytesAndXor blake3gSrc blake3gPermutedOutputs
#guard !cross withBytesAndXor blake3gSrc blake3gWrongWitness
#guard !cross withBytesAndXor blake3gSrc blake3gWrongMiddleWitness
#guard !cross withBytesAndXor blake3gSrc blake3gWrongLastWitness
#guard !cross withBytesAndXor blake3gSrc blake3gWrongRotation16
#guard !cross withBytesAndXor blake3gSrc blake3gWrongRotation12
#guard !cross withBytesAndXor blake3gSrc blake3gWrongRotation8
#guard !cross withBytesAndXor blake3gSrc blake3gWrongRotation7

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
