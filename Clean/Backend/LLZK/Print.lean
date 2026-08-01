import Clean.Backend.LLZK.Basic
import Clean.Backend.LLZK.IR

/-!
# Rendering the backend IR as textual LLZK

The single place in the backend that knows LLZK's concrete syntax. Everything
above it manipulates `Clean.Backend.LLZK.IR` values.

The renderer is total and deterministic: it is a fold over the IR with no
ordering choices, no name generation, and no configuration, so equal modules
render to equal strings and the golden fixtures in `Test/` are stable. Both
properties matter for gate G2 — a golden diff has to mean a semantic change.

Output shape follows the fixtures under `test/Witgen` and `test/Dialect` in the
pinned LLZK revision:

* one statement per line, two-space indent per nesting level;
* one function parameter per line, so that adding or removing a parameter is a
  one-line diff;
* explicit operand types everywhere, which is what `llzk-opt` prints back, so
  `--verify-roundtrip` compares like with like.
-/

namespace LLZK

/-- `!felt.type<"babybear">`, `!array.type<256 x …>`, `!struct.type<@Main>`. -/
def Ty.render : Ty → String
  | .felt field => "!felt.type<\"" ++ field ++ "\">"
  | .array size elem => "!array.type<" ++ toString size ++ " x " ++ elem.render ++ ">"
  | .struct name => "!struct.type<@" ++ name ++ ">"

/-- `%v0`. -/
def Value.render (v : Value) : String := "%v" ++ toString v.index

/-- The LLZK mnemonic, including the dialect prefix. -/
def FeltBinOp.render : FeltBinOp → String
  | .add => "felt.add"
  | .sub => "felt.sub"
  | .mul => "felt.mul"
  | .div => "felt.div"
  | .uintdiv => "felt.uintdiv"
  | .umod => "felt.umod"

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
  | .structNew dst ty =>
    dst.render ++ " = struct.new : " ++ ty.render
  | .readMember dst self selfTy member memberTy =>
    dst.render ++ " = struct.readm " ++ self.render ++ "[@" ++ member ++ "] : "
      ++ selfTy.render ++ ", " ++ memberTy.render
  | .writeMember self selfTy member value memberTy =>
    "struct.writem " ++ self.render ++ "[@" ++ member ++ "] = " ++ value.render ++ " : "
      ++ selfTy.render ++ ", " ++ memberTy.render
  | .globalRead dst name ty =>
    dst.render ++ " = global.read @" ++ name ++ " : " ++ ty.render
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
    ++ (Ty.array g.values.size g.elemTy).render
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
  braced ("struct.def @" ++ s.name ++ " {")
    (joinBlocks #[s.members.map renderMember, renderFunc s.compute, renderFunc s.constrain])
    "}"

/-- Render a module as textual LLZK.

The result ends in a newline and contains no trailing whitespace on any line. -/
def Module.render (m : Module) : String :=
  let body := joinBlocks (#[m.globals.map renderGlobal] ++ m.structs.map renderStruct)
  let lines :=
    braced ("module attributes {llzk.lang, llzk.main = " ++ (Ty.struct m.main).render ++ "} {")
      body "}"
  lines.foldl (fun acc line => acc ++ line ++ "\n") ""

/-- Render a compilation outcome: the module, or every reason there is none.

Failure is rendered rather than thrown so that the negative fixtures — gate G8 —
can pin the exact diagnostics the same way the positive ones pin the exact
module. -/
def renderResult : Except (Array Diagnostic) Module → String
  | .ok m => m.render
  | .error diagnostics =>
    diagnostics.foldl (fun acc d => acc ++ d.render ++ "\n")
      "compilation failed:\n"

end LLZK
