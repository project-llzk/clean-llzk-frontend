import Clean.Circuit.WitnessGeneration
import Clean.Backend.LLZK.Circuit

/-!
# Differential witness generation (gates G5, G6, G7)

Runs Clean's own witness generation on a circuit and renders the result in the
shape `llzk-witgen --output-scope=full-witness --check-output` expects. The
harness then makes both LLZK backends check themselves against it, so a
disagreement between Clean and LLZK is a non-zero exit rather than something a
reader has to spot in two JSON dumps.

Clean's side uses `FlatOperation.witgen`, the array-backed reference interpreter,
which `witgen_eq_dynamicWitnesses` proves computes the same witnesses as
`FlatOperation.dynamicWitnesses`. So the comparison is against a proved-equal
pair of Clean definitions rather than a reimplementation written for the harness
— but `dynamicWitnesses`, not `localWitnesses`, is the reference. The two come
apart on circuits whose witness blocks read their own cells, which is exactly
what `Analyze` now refuses (R2-03); see D014.

Key names come from `Circuit.lean`'s layout functions rather than being spelled
again here, so the expected JSON cannot drift from the emitted members.

What this checks and does not check: `llzk-witgen` executes `compute()` and
ignores `constrain()`. Agreement therefore means the two witness generators
agree — it says nothing about whether the emitted constraints capture Clean's.
-/

namespace LLZK

open Lean (Json)

variable {F : Type} [FiniteField F]

/-- Clean's witness for one input vector: every cell the LLZK module has a member
or parameter for. -/
structure Witness where
  inputs : Array Nat
  cells : Array Nat
  outputs : Array Nat
deriving Repr, DecidableEq

/-- Run Clean's reference witness generation on the circuit's flat operations.

`inputs` are canonical representatives, one per input field element; a value at
or above the field size is refused rather than silently reduced, because
`llzk-witgen` would be given the unreduced number and the two sides would then
disagree for a reason that has nothing to do with the lowering. -/
def witness [CanonicalRepr F] (src : Source F) (inputs : Array Nat) :
    Except Diagnostic Witness := do
  if inputs.size ≠ src.inputSize then
    throw { context := "differential input"
            message := s!"got {inputs.size} input value(s) but the circuit takes {src.inputSize}" }
  for (value, i) in inputs.zipIdx do
    if value ≥ FiniteField.size F then
      throw { context := s!"differential input {i}"
              message := s!"value {value} is not below the field size {FiniteField.size F}" }
  let initial : Array F := inputs.map FiniteField.fromNat
  let values := FlatOperation.witgen (F := F) (ProverHint.empty F) src.operations initial
  let env : ProverEnvironment F := .fromArray values (ProverHint.empty F)
  return {
    inputs
    cells := (values.extract src.inputSize values.size).map FiniteField.val
    outputs := src.outputs.map fun e => FiniteField.val (e.eval env.toEnvironment) }

/-- Field values are JSON strings, not numbers: that is what `llzk-witgen` emits
and what `--check-output` compares against, and it avoids any question of
precision for the larger primes in the registry. -/
private def field (value : Nat) : Json := Json.str (toString value)

private def object (pairs : Array (String × Json)) : Json :=
  Json.mkObj pairs.toList

/-- The `--inputs` object: `{"arg0": "6", "arg1": "7"}`.

Strings, for the same reason the output uses them. `llzk-witgen --inputs` accepts
"a JSON integer or decimal string", and its integer path does not reach the
larger registry primes: `goldilocks`, `bn254` and `grumpkin` values near `p-1` are
rejected outright as JSON numbers and accepted as strings (R2-14). Encoding both
directions the same way removes the question. -/
def inputsJson (inputs : Array Nat) : Json :=
  object (inputs.zipIdx.map fun (value, i) => (inputArgName i, field value))

/-- The `--output-scope=full-witness --check-output` object. -/
def fullWitnessJson (w : Witness) : Json :=
  object #[
    ("inputs", object (w.inputs.zipIdx.map fun (v, i) => (inputArgName i, field v))),
    ("signals", object
      (w.cells.zipIdx.map (fun (v, k) => (witnessMember k, field v))
        ++ w.outputs.zipIdx.map fun (v, j) => (outputMember j, field v)))]

end LLZK
