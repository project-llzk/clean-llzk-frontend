import Clean.Backend.LLZK.Examples

/-!
# `lake exe llzk-emit` — materialize the conformance corpus

Writes one `.llzk` file per entry of `LLZK.Examples.corpus` into a directory, for
`scripts/llzk/e2e.sh` to hand to `llzk-opt` and `llzk-witgen`.

Fails closed. If any corpus entry stops compiling, the diagnostics go to stderr
and nothing is written for it, and the exit status is non-zero — so a harness
cannot mistake a missing artifact for a passing check.
-/

namespace LLZK

/-- Write the corpus, or report every entry that failed to compile. -/
def emitCorpus (directory : System.FilePath) : IO UInt32 := do
  IO.FS.createDirAll directory
  let mut failed := false
  for (name, result) in Examples.corpus do
    let path := directory / (name ++ ".llzk")
    match result with
    | .ok m =>
      IO.FS.writeFile path m.render
      IO.println s!"wrote {path}"
    | .error diagnostics =>
      failed := true
      IO.eprintln s!"error: {name} did not compile:"
      for d in diagnostics do
        IO.eprintln s!"  {d.render}"
  return if failed then 1 else 0

def emitMain (args : List String) : IO UInt32 := do
  match args with
  | [directory] => emitCorpus directory
  | _ =>
    IO.eprintln "usage: llzk-emit <output-directory>"
    IO.eprintln ""
    IO.eprintln "Writes one .llzk file per entry of LLZK.Examples.corpus."
    return 2

end LLZK

def main : List String → IO UInt32 := LLZK.emitMain
