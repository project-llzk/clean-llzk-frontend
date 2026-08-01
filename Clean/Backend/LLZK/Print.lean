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

/-- Accumulates rendered lines with their indentation, so that no renderer has to
thread a prefix string through its recursion. -/
private structure Lines where
  indent : Nat
  out : Array String

private def Lines.empty : Lines := { indent := 0, out := #[] }

/-- Append one line at the current indentation. -/
private def Lines.push (ls : Lines) (line : String) : Lines :=
  { ls with out := ls.out.push ("".pushn ' ' (2 * ls.indent) ++ line) }

/-- Append a blank line. Never indented, so trailing whitespace cannot appear. -/
private def Lines.blank (ls : Lines) : Lines := { ls with out := ls.out.push "" }

/-- Render `body` one level deeper. -/
private def Lines.nest (ls : Lines) (body : Lines → Lines) : Lines :=
  let nested := body { ls with indent := ls.indent + 1 }
  { nested with indent := ls.indent }

private def Lines.pushAll (ls : Lines) (lines : Array String) : Lines :=
  lines.foldl Lines.push ls

private def Lines.toString (ls : Lines) : String :=
  ls.out.foldl (fun acc line => acc ++ line ++ "\n") ""

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

private def renderFunc (f : Func) (ls : Lines) : Lines :=
  let opened :=
    if f.params.isEmpty then
      ls.push ("function.def @" ++ f.name ++ "()" ++ renderSignatureTail f ++ " {")
    else
      let withParams := (ls.push ("function.def @" ++ f.name ++ "(")).nest fun inner =>
        inner.pushAll (renderParams f.params)
      withParams.push (")" ++ renderSignatureTail f ++ " {")
  let body := opened.nest fun inner =>
    let stmts := (inner.pushAll (f.body.map Stmt.render))
    match f.result with
    | some (value, ty) => stmts.push ("function.return " ++ value.render ++ " : " ++ ty.render)
    | none => stmts.push "function.return"
  body.push "}"

private def renderStruct (s : StructDef) (ls : Lines) : Lines :=
  let opened := ls.push ("struct.def @" ++ s.name ++ " {")
  let body := opened.nest fun inner =>
    let withMembers := inner.pushAll (s.members.map renderMember)
    let withCompute := renderFunc s.compute (if s.members.isEmpty then withMembers else withMembers.blank)
    renderFunc s.constrain withCompute.blank
  body.push "}"

/-- Render a module as textual LLZK.

The result ends in a newline and contains no trailing whitespace on any line. -/
def Module.render (m : Module) : String :=
  let header := Lines.empty.push
    ("module attributes {llzk.lang, llzk.main = " ++ (Ty.struct m.main).render ++ "} {")
  let body := header.nest fun inner =>
    let withGlobals := inner.pushAll (m.globals.map renderGlobal)
    m.structs.foldl
      (fun acc s => renderStruct s (if acc.out.isEmpty then acc else acc.blank))
      withGlobals
  (body.push "}").toString

end LLZK
