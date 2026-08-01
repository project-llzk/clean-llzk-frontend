#!/usr/bin/env bash
# Clean → LLZK end-to-end conformance.
#
# Materializes the corpus and runs every gate that needs the LLZK tools. Fails
# closed: a missing or wrong-version tool is an error, never a skipped check,
# because a harness that quietly skips is worse than no harness.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
out_dir="${repo_root}/.lake/llzk"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"
fail() { llzk_fail "$@"; }

cd "${repo_root}"

echo "== G0: state and pins =="
bash "${script_dir}/check-pins.sh"
echo

echo "== tools =="
require_llzk_tools
echo

echo "== G1: Lean =="
python3 scripts/check-consecutive-empty-lines.py
lake build --wfail Clean
lake build CleanTests
echo

echo "== G2: emit the corpus =="
rm -rf "${out_dir}"
lake env lean --run Clean/Backend/LLZK/EmitMain.lean "${out_dir}"
shopt -s nullglob
artifacts=("${out_dir}"/*.llzk)
(( ${#artifacts[@]} > 0 )) || fail "the emitter produced no artifacts"
echo

vectors=0
for artifact in "${artifacts[@]}"; do
  name="$(basename -- "${artifact}" .llzk)"
  echo "== ${name} =="

  echo "-- G3: parse and verify"
  "${LLZK_OPT}" "${artifact}" -o /dev/null
  echo "-- G4: round trip"
  "${LLZK_OPT}" --verify-roundtrip "${artifact}" -o /dev/null

  # G5/G6/G7 in one step per backend: --check-output compares llzk-witgen's
  # full witness against the one Clean's own reference interpreter produced, so
  # a disagreement is a non-zero exit rather than two dumps to eyeball.
  inputs=("${out_dir}/${name}".*.inputs.json)
  (( ${#inputs[@]} > 0 )) \
    || fail "${name} has no input vectors; add some to LLZK.Corpus.corpus or the \
witness gates silently cover nothing"
  for input in "${inputs[@]}"; do
    index="${input##*/${name}.}"; index="${index%%.inputs.json}"
    expected="${out_dir}/${name}.${index}.expected.json"
    [[ -f "${expected}" ]] || fail "missing ${expected}"
    echo "-- G5/G7: interpreter vs Clean, vector ${index}"
    "${LLZK_WITGEN}" "${artifact}" --inputs "${input}" \
      --output-scope=full-witness --check-output "${expected}" >/dev/null
    echo "-- G6/G7: execution engine vs Clean, vector ${index}"
    "${LLZK_WITGEN}" "${artifact}" --inputs "${input}" --backend=execution-engine \
      --output-scope=full-witness --check-output "${expected}" >/dev/null
    vectors=$(( vectors + 1 ))
  done
  echo "   ok"
done
echo

echo "PASS: G0 G1 G2 G3 G4 G5 G6 G7"
echo "  ${#artifacts[@]} circuit(s), ${vectors} input vector(s), both witgen backends."
echo
echo "Not covered: llzk-witgen executes compute() and ignores constrain(), so"
echo "agreement means the two witness generators agree. It says nothing about"
echo "whether the emitted constraints capture Clean's."
