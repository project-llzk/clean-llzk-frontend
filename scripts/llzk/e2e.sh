#!/usr/bin/env bash
# Clean → LLZK end-to-end conformance.
#
# Materializes the corpus and runs every gate that needs the LLZK tools. Fails
# closed: a missing or wrong-version tool is an error, never a skipped check,
# because a harness that quietly skips is worse than no harness. Before trusting
# any witness gate it also proves that llzk-witgen can go red (R2-06).
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
out_dir="${repo_root}/.lake/llzk"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"
fail() { llzk_fail "$@"; }

cd "${repo_root}"

# Runs first, though it is numbered last: every gate below is enforced by these
# scripts, so a broken check here would silently weaken all of them. Until this
# existed, only their happy paths ever ran -- which is how a repair to
# check-pins.sh shipped dying with `llzk_fail: command not found` instead of the
# message it was written to print, and survived two reviews (S21).
echo "== G11: harness error paths =="
bash "${script_dir}/test-scripts.sh"
echo

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
fixtures=("${out_dir}"/syntax/*.llzk)
(( ${#artifacts[@]} > 0 )) || fail "the emitter produced no artifacts"
(( ${#fixtures[@]} > 0 )) || fail "the emitter produced no renderer fixtures"
echo

# The self-test runs on a real corpus artifact and its own expected witness, so
# it exercises exactly the comparison the gates below rely on.
echo "== harness self-test =="
selftest_inputs=("${out_dir}"/*.0.inputs.json)
(( ${#selftest_inputs[@]} > 0 )) || fail "no input vector to run the llzk-witgen self-test on"
selftest_input="${selftest_inputs[0]}"
selftest_name="$(basename -- "${selftest_input}" .0.inputs.json)"
require_llzk_witgen_discriminates \
  "${out_dir}/${selftest_name}.llzk" \
  "${selftest_input}" \
  "${out_dir}/${selftest_name}.0.expected.json" \
  "${out_dir}"
require_llzk_opt_discriminates "${out_dir}" "${out_dir}/${selftest_name}.llzk"
echo

# G10 is in two halves.
#
# G10a — admissibility. `--llzk-full-inlining --llzk-product-program` must
# succeed on every artifact, with no exceptions. It is the entry point to
# `--llzk-to-smt-no-cf` and to everything downstream of it, and it looks up a
# root struct named literally `Main`, ignoring `llzk.main`. Before S12 the
# emitter named the component after the circuit, so *no* emitted module could
# enter any LLZK analysis and no gate noticed (R2-12). This is that gate.
#
# G10b — SMT lowering. Tolerated only for a reason declared in lib.sh, matched
# against the tool's own diagnostic, so a new failure mode is red rather than
# excused.
#
# Neither half checks constraints or witnesses. G9 does both, in Lean.
# Without a floor, a change that put a felt.umod in every module would give
# smt_ok=0, smt_skipped=13 and still print PASS — the count is the only signal
# G10b produces, and nothing compared it to anything (R4b-5).
LLZK_EXPECTED_SMT_OK="${LLZK_EXPECTED_SMT_OK:-9}"
smt_ok=0
smt_skipped=0
smt_log="${out_dir}/.smt.log"
check_smt_pipeline() {
  local artifact="$1" reason
  "${LLZK_OPT}" --llzk-full-inlining --llzk-product-program "${artifact}" \
    -o /dev/null >/dev/null 2>"${smt_log}" \
    || fail "$(basename -- "${artifact}") is not admissible to the LLZK analysis pipeline:
$(sed 's/^/    /' "${smt_log}")"
  if "${LLZK_OPT}" --llzk-full-inlining --llzk-product-program --llzk-to-smt-no-cf \
       "${artifact}" -o /dev/null >/dev/null 2>"${smt_log}"; then
    smt_ok=$(( smt_ok + 1 ))
    return
  fi
  reason="$(llzk_smt_declared_reason "${smt_log}")"
  [[ -n "${reason}" ]] || fail "$(basename -- "${artifact}") fails --llzk-to-smt-no-cf, and not \
for any declared reason:
$(sed 's/^/    /' "${smt_log}")"
  echo "   G10b: out of scope — ${reason}"
  smt_skipped=$(( smt_skipped + 1 ))
}

vectors=0
for artifact in "${artifacts[@]}"; do
  name="$(basename -- "${artifact}" .llzk)"
  echo "== ${name} =="

  echo "-- G3: parse and verify"
  "${LLZK_OPT}" "${artifact}" -o /dev/null
  echo "-- G4: round trip"
  "${LLZK_OPT}" --verify-roundtrip "${artifact}" -o /dev/null
  echo "-- G10: LLZK analysis pipeline"
  check_smt_pipeline "${artifact}"

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

# The renderer fixtures have no Clean circuit behind them and therefore no
# witness to compare. G3/G4 is the whole point: before S11 the renderer golden
# had never been shown to a tool and was in fact invalid LLZK (R2-04).
echo "== renderer fixtures =="
for fixture in "${fixtures[@]}"; do
  name="$(basename -- "${fixture}" .llzk)"
  echo "-- G3/G4: ${name}"
  "${LLZK_OPT}" "${fixture}" -o /dev/null
  "${LLZK_OPT}" --verify-roundtrip "${fixture}" -o /dev/null
  echo "-- G10: ${name}"
  check_smt_pipeline "${fixture}"
done
echo

(( smt_ok >= LLZK_EXPECTED_SMT_OK )) || fail "G10b: only ${smt_ok} module(s) lowered to SMT, \
expected at least ${LLZK_EXPECTED_SMT_OK}. Something that used to be admissible no longer is. \
Set LLZK_EXPECTED_SMT_OK if the corpus legitimately shrank."

echo "PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11"
echo "  ${#artifacts[@]} circuit(s), ${vectors} input vector(s), both witgen backends."
echo "  ${#fixtures[@]} renderer fixture(s), syntax only."
echo "  G8 and G9 are carried inside G1 and G2: the rejection fixtures by"
echo "  'lake build CleanTests', the constraint comparison by both that and the"
echo "  emitter, which refuses to write a circuit whose constraints disagree."
echo "  G10a: all ${#artifacts[@]} + ${#fixtures[@]} module(s) admitted by --llzk-product-program."
echo "  G10b: ${smt_ok} module(s) lowered to SMT, \
${smt_skipped} out of scope for a declared reason."
echo
echo "G9 is not a property of this corpus: both halves of it -- @constrain against"
echo "the circuit's constraints, and @compute against its witness programs -- are"
echo "preconditions of emission, so no module leaves this backend without them."
echo "What remains is the reading of LLZK's own semantics, recorded as D017: that"
echo "felt.add is +, constrain.in is membership, felt.umod reads its operands as"
echo "canonical representatives. G10 shows the modules are admissible to LLZK's"
echo "analysis pipeline; it runs no solver."
