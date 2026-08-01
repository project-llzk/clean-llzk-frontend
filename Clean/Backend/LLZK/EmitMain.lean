import Clean.Backend.LLZK.Corpus

/-!
# `lean --run EmitMain.lean <dir>` — materialize the conformance corpus

For each entry of `LLZK.Corpus.corpus`, writes

* `<Name>.llzk` — the module;
* `<Name>.<i>.inputs.json` — the `i`th input vector, for `llzk-witgen --inputs`;
* `<Name>.<i>.expected.json` — Clean's own witness for it, in the shape
  `llzk-witgen --output-scope=full-witness --check-output` compares against.

`scripts/llzk/e2e.sh` then makes both LLZK backends check themselves against
Clean, so gate G7 is a non-zero exit rather than two JSON dumps for a reader to
compare.

Fails closed: a corpus entry that stops compiling, or an input vector Clean
refuses, is reported on stderr and makes the exit status non-zero. Nothing
partial is left that a harness could mistake for a passing check.
-/

namespace LLZK

open Lean (Json)

/-- Write one entry. Returns whether anything went wrong. -/
private def emitEntry (directory : System.FilePath) (entry : Corpus.Entry) : IO Bool := do
  let mut failed := false
  match entry.module with
  | .error diagnostics =>
    IO.eprintln s!"error: {entry.name} did not compile:"
    for d in diagnostics do IO.eprintln s!"  {d.render}"
    return true
  | .ok m =>
    let path := directory / (entry.name ++ ".llzk")
    IO.FS.writeFile path m.render
    IO.println s!"wrote {path}"
  for (inputs, i) in entry.inputs.zipIdx do
    match entry.witness inputs with
    | .error d =>
      IO.eprintln s!"error: {entry.name} input vector {i}: {d.render}"
      failed := true
    | .ok w =>
      IO.FS.writeFile (directory / s!"{entry.name}.{i}.inputs.json")
        (inputsJson inputs).compress
      IO.FS.writeFile (directory / s!"{entry.name}.{i}.expected.json")
        (fullWitnessJson w).compress
  return failed

/-- Write the whole corpus, or report every entry that failed. -/
def emitCorpus (directory : System.FilePath) : IO UInt32 := do
  IO.FS.createDirAll directory
  let mut failed := false
  for entry in Corpus.corpus do
    if ← emitEntry directory entry then failed := true
  if failed then return 1
  IO.println s!"{Corpus.corpus.size} circuit(s), \
    {Corpus.corpus.foldl (fun n e => n + e.inputs.size) 0} input vector(s)"
  return 0

def emitMain (args : List String) : IO UInt32 := do
  match args with
  | [directory] => emitCorpus directory
  | _ =>
    IO.eprintln "usage: llzk-emit <output-directory>"
    IO.eprintln ""
    IO.eprintln "Writes the LLZK module, input vectors and Clean's expected"
    IO.eprintln "witnesses for every entry of LLZK.Corpus.corpus."
    return 2

end LLZK

def main : List String → IO UInt32 := LLZK.emitMain
