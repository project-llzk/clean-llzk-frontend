import Clean.Backend.LLZK.Corpus

/-!
# `lean --run EmitMain.lean <dir>` — materialize the conformance corpus

For each entry of `LLZK.Corpus.corpus`, writes

* `<Name>.llzk` — the module;
* `<Name>.<i>.inputs.json` — the `i`th input vector, for `llzk-witgen --inputs`;
* `<Name>.<i>.expected.json` — Clean's own witness for it, in the shape
  `llzk-witgen --output-scope=full-witness --check-output` compares against.

For each entry of `LLZK.Corpus.syntaxFixtures`, writes `<dir>/syntax/<Name>.llzk`
— a renderer fixture with no input vectors, checked by `llzk-opt` alone.

`scripts/llzk/e2e.sh` then makes both LLZK backends check themselves against
Clean, so gate G7 is a non-zero exit rather than two JSON dumps for a reader to
compare.

Fails closed: a corpus entry that stops compiling, or an input vector Clean
refuses, is reported on stderr and makes the exit status non-zero. A failing
entry does leave its `.llzk` and any already-written vectors on disk — what stops
the harness acting on them is the non-zero exit and `set -e`, plus the fact that
`e2e.sh` deletes and regenerates the whole output directory every run.
-/

namespace LLZK

open Lean (Json)

/-- Write one entry. Returns whether anything went wrong. -/
private def emitEntry (directory : System.FilePath) (entry : Corpus.Entry) : IO Bool := do
  let mut failed := false
  if entry.constraintsAgree = some false then
    IO.eprintln s!"error: {entry.name}: the emitted @constrain is not the same constraint \
      system as the Clean circuit's (gate G9); see Clean/Backend/LLZK/Constraints.lean"
    failed := true
  if entry.witnessAgree = some false then
    IO.eprintln s!"error: {entry.name}: the emitted @compute does not compute the Clean \
      circuit's witnesses (gate G9, witness side); see Clean/Backend/LLZK/WitnessCheck.lean"
    failed := true
  match entry.module with
  | .error diagnostics =>
    IO.eprintln s!"error: {entry.name} did not compile:"
    for d in diagnostics do IO.eprintln s!"  {d.render}"
    return true
  | .ok m =>
    let path := directory / (entry.name ++ ".llzk")
    IO.FS.writeFile path m.render
    IO.println s!"wrote {path}"
  for ((inputs, expected), i) in entry.vectors.zipIdx do
    match expected with
    | .error d =>
      IO.eprintln s!"error: {entry.name} input vector {i}: {d.render}"
      failed := true
    | .ok w =>
      IO.FS.writeFile (directory / s!"{entry.name}.{i}.inputs.json")
        (inputsJson inputs).compress
      IO.FS.writeFile (directory / s!"{entry.name}.{i}.expected.json")
        (fullWitnessJson w).compress
  return failed

/-- Write one renderer fixture. Returns whether anything went wrong. -/
private def emitSyntaxFixture (directory : System.FilePath)
    (fixture : String × Except Diagnostic Module) : IO Bool := do
  let (name, result) := fixture
  match result with
  | .error d =>
    IO.eprintln s!"error: renderer fixture {name} did not build: {d.render}"
    return true
  | .ok m =>
    let path := directory / (name ++ ".llzk")
    IO.FS.writeFile path m.render
    IO.println s!"wrote {path}"
    return false

/-- Write the whole corpus, or report every entry that failed. -/
def emitCorpus (directory : System.FilePath) : IO UInt32 := do
  IO.FS.createDirAll directory
  let syntaxDirectory := directory / "syntax"
  IO.FS.createDirAll syntaxDirectory
  let mut failed := false
  for entry in Corpus.corpus do
    if ← emitEntry directory entry then failed := true
  for fixture in Corpus.syntaxFixtures do
    if ← emitSyntaxFixture syntaxDirectory fixture then failed := true
  if failed then return 1
  let checked := Corpus.corpus.filter (·.constraintsAgree = some true)
  IO.println s!"{Corpus.corpus.size} circuit(s), \
    {Corpus.corpus.foldl (fun n e => n + e.vectors.size) 0} input vector(s), \
    {Corpus.syntaxFixtures.size} renderer fixture(s)"
  IO.println s!"G9: {checked.size} of {Corpus.corpus.size} circuit(s) have a Clean source; for \
    each, the emitted @constrain is the same constraint system and the emitted @compute \
    computes the same witnesses"
  return 0

def emitMain (args : List String) : IO UInt32 := do
  match args with
  | [directory] => emitCorpus directory
  | _ =>
    IO.eprintln "usage: llzk-emit <output-directory>"
    IO.eprintln ""
    IO.eprintln "Writes the LLZK module, input vectors and Clean's expected"
    IO.eprintln "witnesses for every entry of LLZK.Corpus.corpus, and the"
    IO.eprintln "renderer fixtures under <output-directory>/syntax."
    return 2

end LLZK

def main : List String → IO UInt32 := LLZK.emitMain
