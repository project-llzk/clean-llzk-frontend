import Clean.Backend.LLZK.Showcase

/-! Generate `doc/llzk/EXAMPLES.md`, or print it when no path is supplied. -/

private def generate : IO String :=
  match LLZK.Showcase.markdown with
  | .ok text => pure text
  | .error message => throw <| IO.userError message

def main : List String → IO UInt32
  | [] => do
      IO.print (← generate)
      return 0
  | [path] => do
      IO.FS.writeFile path (← generate)
      return 0
  | _ => do
      IO.eprintln "usage: ShowcaseMain.lean [output-file]"
      return 2
