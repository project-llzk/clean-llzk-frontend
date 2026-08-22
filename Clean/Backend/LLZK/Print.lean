import Clean.Backend.LLZK.Basic
import Clean.Backend.LLZK.IR

/-!
# Rendering the backend IR as textual LLZK

The single place in the backend that knows LLZK's concrete syntax. Everything
above it manipulates `Clean.Backend.LLZK.IR` values.

The raw renderer is total and deterministic: it is a fold over the IR with no
ordering choices, no name generation, and no configuration, so equal modules
render to equal strings and the golden fixtures in `Test/` are stable. The
public `Module.render` then parses the protected globals, component members,
constraint parameters, and complete `@constrain` body back out of that text and
refuses to return it unless they equal the typed IR. This is A5: a dropped or
mis-rendered constraint, table row, or public-interface member is a diagnostic
before an artifact can be written, even though the pinned LLZK binaries accept
many such semantic mutations.

Output shape follows the fixtures under `test/Witgen` and `test/Dialect` in the
pinned LLZK revision:

* one statement per line, two-space indent per nesting level;
* one function parameter per line, so that adding or removing a parameter is a
  one-line diff;
* explicit operand types everywhere, which is what `llzk-opt` prints back, so
  `--verify-roundtrip` compares like with like.
-/

namespace LLZK

/-- `!felt.type<"babybear">`, `!array.type<256,3 x …>`, `!struct.type<@Main>`. -/
def Ty.render : Ty → String
  | .felt field => "!felt.type<\"" ++ field ++ "\">"
  | .array dimensions elem =>
      "!array.type<" ++ String.intercalate "," (dimensions.toList.map toString)
        ++ " x " ++ elem.render ++ ">"
  | .struct name => "!struct.type<@" ++ name ++ ">"

/-- `%v0`. -/
def Value.render (v : Value) : String := "%v" ++ toString v.index

/-- The LLZK mnemonic, including the dialect prefix. -/
def FeltBinOp.render : FeltBinOp → String
  | .add => "felt.add"
  | .mul => "felt.mul"
  | .uintdiv => "felt.uintdiv"
  | .umod => "felt.umod"
  | .bitAnd => "felt.bit_and"
  | .bitOr => "felt.bit_or"
  | .bitXor => "felt.bit_xor"
  | .shl => "felt.shl"
  | .shr => "felt.shr"

/-- The attribute name as it appears in a `function.def` attribute dictionary. -/
def FuncAttr.render : FuncAttr → String
  | .allowNonNativeFieldOps => "function.allow_non_native_field_ops"

/-- The attribute dictionary on a `struct.member`. -/
def Visibility.render : Visibility → String
  | .pub => "{llzk.pub}"
  | .signal => "{signal}"

/-- Operand-type suffix for the binary ops, which name both operand types. -/
private def binaryTypes (ty : Ty) : String :=
  " : " ++ ty.render ++ ", " ++ ty.render

def Stmt.render : Stmt → String
  | .feltConst dst value ty =>
    dst.render ++ " = felt.const " ++ toString value ++ " : " ++ ty.render
  | .feltBin dst op lhs rhs ty =>
    dst.render ++ " = " ++ op.render ++ " " ++ lhs.render ++ ", " ++ rhs.render ++ binaryTypes ty
  | .structNew dst =>
    dst.render ++ " = struct.new : " ++ rootTy.render
  | .readMember dst self member memberTy =>
    dst.render ++ " = struct.readm " ++ self.render ++ "[@" ++ member ++ "] : "
      ++ rootTy.render ++ ", " ++ memberTy.render
  | .writeMember self member value memberTy =>
    "struct.writem " ++ self.render ++ "[@" ++ member ++ "] = " ++ value.render ++ " : "
      ++ rootTy.render ++ ", " ++ memberTy.render
  | .globalRead dst name ty =>
    dst.render ++ " = global.read @" ++ name ++ " : " ++ ty.render
  | .arrayNew dst elements elemTy =>
    dst.render ++ " = array.new "
      ++ String.intercalate ", " (elements.toList.map Value.render)
      ++ " : " ++ (Ty.array #[elements.size] elemTy).render
  | .constrainEq lhs rhs ty =>
    "constrain.eq " ++ lhs.render ++ ", " ++ rhs.render ++ binaryTypes ty
  | .constrainIn array arrayTy element elementTy =>
    "constrain.in " ++ array.render ++ ", " ++ element.render ++ " : "
      ++ arrayTy.render ++ ", " ++ elementTy.render

/-! ## Line assembly

Every construct renders to an `Array String` of *unindented* lines and its
enclosing construct indents it. That keeps each renderer local — none has to know
how deep it sits — and it is why blank-line placement is decided in exactly one
place, `joinBlocks`, rather than by each caller guessing whether it is first. -/

/-- Indent a block by one level, leaving blank lines blank so that no rendered
line ever carries trailing whitespace. -/
private def indentBlock (lines : Array String) : Array String :=
  lines.map fun line => if line.isEmpty then line else "  " ++ line

/-- Concatenate blocks with one blank line between consecutive non-empty ones.
Empty blocks — a component with no members, a module with no globals —
contribute nothing, not a stray separator. -/
private def joinBlocks (blocks : Array (Array String)) : Array String :=
  (blocks.filter (!·.isEmpty)).foldl
    (fun acc block => if acc.isEmpty then block else acc.push "" ++ block) #[]

/-- `header` / indented `body` / `footer`. -/
private def braced (header : String) (body : Array String) (footer : String) : Array String :=
  #[header] ++ indentBlock body ++ #[footer]

/-- The array literal is emitted on one line however long it is: a lookup table of
a few hundred rows is a single logical value, and wrapping it would make the
layout depend on the row count. -/
private def renderGlobal (g : ConstArray) : String :=
  "global.def const @" ++ g.name ++ " : "
    ++ g.ty.render
    ++ " = [" ++ String.intercalate ", " (g.values.toList.map toString) ++ "]"

private def renderMember (m : Member) : String :=
  "struct.member @" ++ m.name ++ " : " ++ m.ty.render ++ " " ++ m.visibility.render

/-- One parameter, without its trailing comma. -/
private def renderParam (p : Param) : String :=
  let argName := match p.argName with
    | some name => " {function.arg_name = \"" ++ name ++ "\"}"
    | none => ""
  p.value.render ++ ": " ++ p.ty.render ++ argName

/-- The text between `function.def @name(` and the opening brace: the return type
and the attribute dictionary, either of which may be absent. -/
private def renderSignatureTail (f : Func) : String :=
  let ret := match f.result with
    | some (_, ty) => " -> " ++ ty.render
    | none => ""
  let attrs :=
    if f.attrs.isEmpty then ""
    else " attributes {" ++ String.intercalate ", " (f.attrs.toList.map FuncAttr.render) ++ "}"
  ret ++ attrs

/-- Parameters go one per line, so adding or removing one is a one-line diff in a
golden fixture. The comma belongs to all but the last. -/
private def renderParams (params : Array Param) : Array String :=
  params.toList.map renderParam
    |>.zipIdx
    |>.map (fun (text, i) => if i + 1 = params.size then text else text ++ ",")
    |>.toArray

private def renderReturn (f : Func) : String :=
  match f.result with
  | some (value, ty) => "function.return " ++ value.render ++ " : " ++ ty.render
  | none => "function.return"

private def renderFunc (f : Func) : Array String :=
  let opening :=
    if f.params.isEmpty then
      #["function.def @" ++ f.name ++ "()" ++ renderSignatureTail f ++ " {"]
    else
      #["function.def @" ++ f.name ++ "("]
        ++ indentBlock (renderParams f.params)
        ++ #[")" ++ renderSignatureTail f ++ " {"]
  opening ++ indentBlock (f.body.map Stmt.render ++ #[renderReturn f]) ++ #["}"]

private def renderStruct (s : StructDef) : Array String :=
  braced ("struct.def @" ++ rootComponent ++ " {")
    (joinBlocks #[s.members.map renderMember, renderFunc s.compute, renderFunc s.constrain])
    "}"

/-- The module attribute dictionary.

`llzk.lang = "clean"` is the spelling `doc/llzk/ARCHITECTURE.md` §5 specifies;
the bare unit attribute emitted before S12 was an unrecorded deviation (R2-10).

`llzk.fields` from the same contract is *not* emitted, and cannot be: declaring
`#felt.field<"babybear", 2013265921>` conflicts with LLZK's own registry entry
and `llzk-opt` rejects the module. See D016. -/
private def moduleAttrs : String :=
  "{llzk.lang = \"clean\", llzk.main = " ++ rootTy.render ++ "}"

/-- Render a module as textual LLZK, before the A5 constraint-surface check.

The result ends in a newline and contains no trailing whitespace on any line. -/
private def Module.renderUnchecked (m : Module) : String :=
  let body := joinBlocks (#[m.globals.map renderGlobal, renderStruct m.root])
  let lines := braced ("module attributes " ++ moduleAttrs ++ " {") body "}"
  lines.foldl (fun acc line => acc ++ line ++ "\n") ""

/-! ## A5: read the rendered semantic surface back

`llzk-opt` checks that `@constrain` is well typed, but it accepts an empty body,
a dropped equation, changed arithmetic, and a member read silently redirected
to another member of the same type. It also accepts changing a `{signal}` member
to `{llzk.pub}`, which changes `--output-scope=public`. G9 cannot see a renderer
defect because it compares typed `Module`s before rendering. The reader below
therefore protects every global, every member declaration, every constraint
parameter, and every statement constructor in `@constrain`.

This reader is deliberately textual. It does not call a renderer in order to
decide what it saw: it splits the concrete spelling back into indices and names,
and parses felt, struct, and recursively nested array types back into `Ty`.
Parsing types rather than comparing with `Ty.render` is load-bearing: otherwise
a field-name bug in `Ty.render` would affect both sides of the comparison and
remain green.
-/

namespace RenderCheck

/-- The information in the rendered semantic forms A5 protects.

SSA values are represented by their numeric indices so this independent reader
does not need access to `Value`'s private constructor. -/
inductive SurfaceItem where
  | global (name : String) (ty : Ty) (values : Array Nat)
  | member (name : String) (ty : Ty) (visibility : Visibility)
  | constrainParam (index : Nat) (ty : Ty) (argName : Option String)
  | feltConst (dst value : Nat) (ty : Ty)
  | feltBin (dst : Nat) (op : FeltBinOp) (lhs rhs : Nat) (ty : Ty)
  | structNew (dst : Nat)
  | readMember (dst self : Nat) (member : String) (rootTy memberTy : Ty)
  | writeMember (self : Nat) (member : String) (value : Nat) (rootTy memberTy : Ty)
  | globalRead (dst : Nat) (name : String) (ty : Ty)
  | arrayNew (dst : Nat) (elements : Array Nat) (resultTy : Ty)
  | constrainEq (lhs rhs : Nat) (lhsTy rhsTy : Ty)
  | constrainIn (array element : Nat) (arrayTy elementTy : Ty)
deriving DecidableEq, Repr

private def two : List String → Option (String × String)
  | [a, b] => some (a, b)
  | _ => none

private def valueIndex (text : String) : Option Nat := do
  let (empty, index) ← two (text.splitOn "%v")
  if empty.isEmpty then index.toNat? else none

private def consume : List Char → List Char → Option (List Char)
  | [], input => some input
  | expected :: expectedRest, actual :: actualRest =>
    if expected = actual then consume expectedRest actualRest else none
  | _ :: _, [] => none

/-- Consume through `stop`, returning the characters before it and the suffix
after it. -/
private def takeUntil (stop : Char) : List Char → Option (List Char × List Char)
  | [] => none
  | c :: rest =>
    if c = stop then some ([], rest)
    else do
      let (before, after) ← takeUntil stop rest
      return (c :: before, after)

private partial def parseTyChars (input : List Char) : Option (Ty × List Char) :=
  match consume "!felt.type<\"".toList input with
  | some rest => do
    let (field, rest) ← takeUntil '\"' rest
    let rest ← consume ">".toList rest
    return (.felt (String.ofList field), rest)
  | none =>
    match consume "!struct.type<@".toList input with
    | some rest => do
      let (name, rest) ← takeUntil '>' rest
      return (.struct (String.ofList name), rest)
    | none => do
      let rest ← consume "!array.type<".toList input
      let (dimensionsText, rest) ← takeUntil 'x' rest
      let dimensions ← (String.ofList dimensionsText).splitOn "," |>.mapM fun text =>
        text.trimAscii.toString.toNat?
      guard (!dimensions.isEmpty)
      let rest ← consume " ".toList rest
      let (element, rest) ← parseTyChars rest
      let rest ← consume ">".toList rest
      return (.array dimensions.toArray element, rest)

/-- The independent inverse for the complete type grammar `Ty.render` emits. -/
def parseTy (text : String) : Option Ty := do
  let (ty, rest) ← parseTyChars text.toList
  if rest.isEmpty then some ty else none

private def parseVisibility : String → Option Visibility
  | "{signal}" => some .signal
  | "{llzk.pub}" => some .pub
  | _ => none

private def parseFeltBinOp : String → Option FeltBinOp
  | "felt.add" => some .add
  | "felt.mul" => some .mul
  | "felt.uintdiv" => some .uintdiv
  | "felt.umod" => some .umod
  | "felt.bit_and" => some .bitAnd
  | "felt.bit_or" => some .bitOr
  | "felt.bit_xor" => some .bitXor
  | "felt.shl" => some .shl
  | "felt.shr" => some .shr
  | _ => none

private def parseMember (line : String) : Option SurfaceItem := do
  let (empty, tail) ← two (line.splitOn "struct.member @")
  guard empty.isEmpty
  let (name, typedVisibility) ← two (tail.splitOn " : ")
  let parts := typedVisibility.splitOn " "
  let visibilityText ← parts.getLast?
  let typeText := String.intercalate " " parts.dropLast
  return .member name (← parseTy typeText) (← parseVisibility visibilityText)

private def parseParam (line : String) : Option SurfaceItem := do
  let line := match line.toList.reverse with
    | ',' :: rest => String.ofList rest.reverse
    | _ => line
  let (valueText, typedName) ← two (line.splitOn ": ")
  let index ← valueIndex valueText
  match typedName.splitOn " {function.arg_name = \"" with
  | [typeText] => return .constrainParam index (← parseTy typeText) none
  | [typeText, namedTail] => do
      let (name, empty) ← two (namedTail.splitOn "\"}")
      guard empty.isEmpty
      return .constrainParam index (← parseTy typeText) (some name)
  | _ => none

private def parseFeltConst (line : String) : Option SurfaceItem := do
  let (dstText, tail) ← two (line.splitOn " = felt.const ")
  let (valueText, typeText) ← two (tail.splitOn " : ")
  return .feltConst (← valueIndex dstText) (← valueText.toNat?) (← parseTy typeText)

private def parseFeltBin (line : String) : Option SurfaceItem := do
  let (dstText, tail) ← two (line.splitOn " = felt.")
  let (operationAndOperands, types) ← two (tail.splitOn " : ")
  let (operationChars, operandChars) ← takeUntil ' ' operationAndOperands.toList
  let operation := String.ofList operationChars
  let operands := String.ofList operandChars
  let (lhsText, rhsText) ← two (operands.splitOn ", ")
  let (lhsTypeText, rhsTypeText) ← two (types.splitOn ", ")
  let lhsTy ← parseTy lhsTypeText
  let rhsTy ← parseTy rhsTypeText
  guard (lhsTy = rhsTy)
  return .feltBin (← valueIndex dstText) (← parseFeltBinOp ("felt." ++ operation))
    (← valueIndex lhsText) (← valueIndex rhsText) lhsTy

private def parseStructNew (line : String) : Option SurfaceItem := do
  let (dstText, typeText) ← two (line.splitOn " = struct.new : ")
  guard ((← parseTy typeText) = rootTy)
  return .structNew (← valueIndex dstText)

private def parseReadMember (line : String) : Option SurfaceItem := do
  let (dstText, tail) ← two (line.splitOn " = struct.readm ")
  let (selfText, tail) ← two (tail.splitOn "[@")
  let (member, types) ← two (tail.splitOn "] : ")
  let (rootTypeText, memberTypeText) ← two (types.splitOn ", ")
  let dst ← valueIndex dstText
  let self ← valueIndex selfText
  let rootType ← parseTy rootTypeText
  let memberType ← parseTy memberTypeText
  return .readMember dst self member rootType memberType

private def parseWriteMember (line : String) : Option SurfaceItem := do
  let (empty, tail) ← two (line.splitOn "struct.writem ")
  guard empty.isEmpty
  let (selfText, tail) ← two (tail.splitOn "[@")
  let (member, valueAndTypes) ← two (tail.splitOn "] = ")
  let (valueText, types) ← two (valueAndTypes.splitOn " : ")
  let (rootTypeText, memberTypeText) ← two (types.splitOn ", ")
  return .writeMember (← valueIndex selfText) member (← valueIndex valueText)
    (← parseTy rootTypeText) (← parseTy memberTypeText)

private def parseGlobal (line : String) : Option SurfaceItem := do
  let (empty, tail) ← two (line.splitOn "global.def const @")
  guard empty.isEmpty
  let (name, typedInitializer) ← two (tail.splitOn " : ")
  let (typeText, initializer) ← two (typedInitializer.splitOn " = [")
  let (valuesText, after) ← two (initializer.splitOn "]")
  guard after.isEmpty
  let ty ← parseTy typeText
  let values ← valuesText.splitOn ", " |>.mapM String.toNat?
  return .global name ty values.toArray

private def parseGlobalRead (line : String) : Option SurfaceItem := do
  let (dstText, tail) ← two (line.splitOn " = global.read @")
  let (name, typeText) ← two (tail.splitOn " : ")
  return .globalRead (← valueIndex dstText) name (← parseTy typeText)

private def parseConstrainEq (line : String) : Option SurfaceItem := do
  let (empty, tail) ← two (line.splitOn "constrain.eq ")
  if !empty.isEmpty then none else
    let (operands, types) ← two (tail.splitOn " : ")
    let (lhsText, rhsText) ← two (operands.splitOn ", ")
    let (lhsTypeText, rhsTypeText) ← two (types.splitOn ", ")
    let lhs ← valueIndex lhsText
    let rhs ← valueIndex rhsText
    let lhsType ← parseTy lhsTypeText
    let rhsType ← parseTy rhsTypeText
    return .constrainEq lhs rhs lhsType rhsType

private def parseArrayNew (line : String) : Option SurfaceItem := do
  let (dstText, tail) ← two (line.splitOn " = array.new ")
  let (elementsText, typeText) ← two (tail.splitOn " : ")
  let dst ← valueIndex dstText
  let elements ← elementsText.splitOn ", " |>.mapM valueIndex
  let resultTy ← parseTy typeText
  return .arrayNew dst elements.toArray resultTy

private def parseConstrainIn (line : String) : Option SurfaceItem := do
  let (empty, tail) ← two (line.splitOn "constrain.in ")
  if !empty.isEmpty then none else
    let (operands, types) ← two (tail.splitOn " : ")
    let (arrayText, elementText) ← two (operands.splitOn ", ")
    let (arrayTypeText, elementTypeText) ← two (types.splitOn ", ")
    let array ← valueIndex arrayText
    let element ← valueIndex elementText
    let arrayType ← parseTy arrayTypeText
    let elementType ← parseTy elementTypeText
    return .constrainIn array element arrayType elementType

/-- Parse one unindented statement from the protected concrete syntax. -/
def parseStmt (line : String) : Option SurfaceItem :=
  parseGlobal line <|> parseMember line <|> parseFeltConst line <|> parseFeltBin line <|>
    parseStructNew line <|> parseReadMember line <|> parseWriteMember line <|>
    parseGlobalRead line <|> parseArrayNew line <|> parseConstrainEq line <|>
    parseConstrainIn line

private def mentions (needle line : String) : Bool :=
  (line.splitOn needle).length > 1

/-- Inside `@constrain`, every non-terminator body line must be one of the
modelled statement forms. This is intentionally fail-closed for future IR
constructors as well as malformed spellings of current ones. -/
private def parseRelevant (line : String) : Option SurfaceItem :=
  parseStmt line.trimAscii.toString

private def parseOuterRelevant (line : String) : Option (Option SurfaceItem) :=
  let line := line.trimAscii.toString
  if mentions "global.def" line || mentions "struct.member" line then
    (parseStmt line).map some
  else some none

private def parseLines :
    List String → Array SurfaceItem → Bool → Bool → Bool → Option (Array SurfaceItem)
  | [], acc, inConstrain, inBody, sawConstrain =>
    if sawConstrain && !inConstrain && !inBody then some acc else none
  | line :: rest, acc, inConstrain, inBody, sawConstrain =>
    let line := line.trimAscii.toString
    if line = "function.def @constrain(" then
      if sawConstrain then none else parseLines rest acc true false true
    else if inConstrain && !inBody && line = ") {" then
      parseLines rest acc true true sawConstrain
    else if inConstrain && !inBody then do
      let parsed ← parseParam line
      parseLines rest (acc.push parsed) true false sawConstrain
    else if inBody && line = "function.return" then
      parseLines rest acc true true sawConstrain
    else if inBody && line = "}" then
      parseLines rest acc false false sawConstrain
    else if inBody then do
      let parsed ← parseRelevant line
      parseLines rest (acc.push parsed) true true sawConstrain
    else do
      let parsed ← parseOuterRelevant line
      parseLines rest (match parsed with | some item => acc.push item | none => acc)
        false false sawConstrain

/-- Parse every protected statement from a rendered module, failing if a line
mentions a protected operation but does not have its exact concrete grammar. -/
def parse (text : String) : Option (Array SurfaceItem) :=
  parseLines (text.splitOn "\n") #[] false false false

/-- Project the same surface directly from one typed statement. -/
def SurfaceItem.ofStmt : Stmt → SurfaceItem
  | Stmt.feltConst dst value ty => .feltConst dst.index value ty
  | Stmt.feltBin dst op lhs rhs ty => .feltBin dst.index op lhs.index rhs.index ty
  | Stmt.structNew dst => .structNew dst.index
  | Stmt.readMember dst self memberName memberTy =>
    .readMember dst.index self.index memberName rootTy memberTy
  | Stmt.writeMember self memberName value memberTy =>
    .writeMember self.index memberName value.index rootTy memberTy
  | Stmt.globalRead dst name ty => .globalRead dst.index name ty
  | Stmt.arrayNew dst elements elemTy =>
    .arrayNew dst.index (elements.map (·.index)) (.array #[elements.size] elemTy)
  | Stmt.constrainEq lhs rhs ty =>
    .constrainEq lhs.index rhs.index ty ty
  | Stmt.constrainIn array arrayTy element elementTy =>
    .constrainIn array.index element.index arrayTy elementTy

private def SurfaceItem.ofGlobal (g : ConstArray) : SurfaceItem :=
  .global g.name g.ty g.values

private def SurfaceItem.ofMember (m : Member) : SurfaceItem :=
  .member m.name m.ty m.visibility

private def SurfaceItem.ofParam (p : Param) : SurfaceItem :=
  .constrainParam p.value.index p.ty p.argName

/-- The protected statements in `@constrain`, in render order. Keeping function
context is load-bearing: a line moved into `@compute` must not compare equal just
because the flattened sequence of protected statements stayed the same. -/
def expected (m : Module) : Array SurfaceItem :=
  m.globals.map SurfaceItem.ofGlobal
    ++ m.root.members.map SurfaceItem.ofMember
    ++ m.root.constrain.params.map SurfaceItem.ofParam
    ++ m.root.constrain.body.map SurfaceItem.ofStmt

/-- Check externally supplied text against a typed module. Public so mutation
tests can establish that the check goes red; artifact production calls it only
through `Module.render`. -/
def check (m : Module) (text : String) : Except Diagnostic Unit :=
  match parse text with
  | none =>
    .error { context := "LLZK renderer"
             message := "the rendered semantic surface is malformed; refusing the artifact" }
  | some actual =>
    if actual = expected m then .ok ()
    else
      .error { context := "LLZK renderer"
               message := "the rendered semantic surface differs from the typed module; refusing the artifact" }

end RenderCheck

/-- Render and independently read back the semantic surface G9 cannot observe.

Returning `Except` is part of the assurance boundary: an artifact producer
cannot accidentally ignore a mismatch by using the supported renderer. -/
def Module.render (m : Module) : Except Diagnostic String := do
  let text := m.renderUnchecked
  RenderCheck.check m text
  return text

/-- Every text successfully returned by `Module.render` has the protected
surface extracted from the typed module. This is the A5 round-trip theorem; the
positive and mutation tests in `Test/Print.lean` establish that success is not
vacuous and that every semantic form the compiler currently emits can make the
check red. -/
theorem Module.render_semanticSurface {m : Module} {text : String}
    (h : m.render = .ok text) :
    RenderCheck.parse text = some (RenderCheck.expected m) := by
  simp only [Module.render] at h
  unfold RenderCheck.check at h
  split at h
  · contradiction
  · split at h
    · rename_i actual hparse heq
      change Except.ok m.renderUnchecked = Except.ok text at h
      injection h with htext
      subst text
      rw [hparse, heq]
    · contradiction

/-- Compatibility spelling for the original A5 theorem name. The protected
surface now includes members, parameters, and every `@constrain` statement. -/
theorem Module.render_constraintSurface {m : Module} {text : String}
    (h : m.render = .ok text) :
    RenderCheck.parse text = some (RenderCheck.expected m) :=
  Module.render_semanticSurface h

/-- Render a compilation outcome: the module, or every reason there is none.

Failure is rendered rather than thrown so that the negative fixtures — gate G8 —
can pin the exact diagnostics the same way the positive ones pin the exact
module. -/
def renderResult : Except (Array Diagnostic) Module → String
  | .ok m =>
    match m.render with
    | .ok text => text
    | .error diagnostic => "compilation failed:\n" ++ diagnostic.render ++ "\n"
  | .error diagnostics =>
    diagnostics.foldl (fun acc d => acc ++ d.render ++ "\n")
      "compilation failed:\n"

end LLZK
