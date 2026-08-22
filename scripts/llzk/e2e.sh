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

# Before anything else, because everything below writes into the worktree --
# .lake/llzk is rebuilt from scratch at G2 -- and because the evidence a run
# produces is only attributable to a commit if one session owned the tree while
# it ran. S22's evidence file had to carry a caveat saying its PASS could not be
# attributed to its own commit. See doc/llzk/CONCURRENCY.md.
#
# Under an agent harness, set LLZK_SESSION; the POSIX session id this defaults to
# is per-command there, so a claim made in an earlier command is not recognised.
bash "${script_dir}/worktree-lock.sh" require
echo

# Runs first, though it is numbered last: every gate below is enforced by these
# scripts, so a broken check here would silently weaken all of them. Until this
# existed, only their happy paths ever ran -- which is how a repair to
# check-pins.sh shipped dying with `llzk_fail: command not found` instead of the
# message it was written to print, and survived two reviews (S21).
echo "== G11: harness error paths =="
bash "${script_dir}/test-scripts.sh"
echo

echo "== CI dependency pins =="
bash "${script_dir}/check-actions-pinned.sh"
echo

echo "== G12: the gate-skipping entry points are confined =="
bash "${script_dir}/check-confinement.sh"
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

# The public example table is executable documentation, not a hand-maintained
# copy of corpus counts. Generate it from the working tree and require the
# checked-in page to be byte-identical. A new corpus entry therefore needs a
# purpose label and a reviewed documentation diff before the release gate passes.
showcase_tmp="$(mktemp)"
trap 'rm -f -- "${showcase_tmp}"' EXIT
lake env lean --run Clean/Backend/LLZK/ShowcaseMain.lean "${showcase_tmp}"
if ! diff -u doc/llzk/EXAMPLES.md "${showcase_tmp}"; then
  fail "doc/llzk/EXAMPLES.md is stale; regenerate it with ShowcaseMain.lean"
fi
rm -f -- "${showcase_tmp}"
trap - EXIT
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
# Both ends of the corpus, not just the alphabetically first. R5d's D-4: with a
# single fixed probe, a wrapper honest on that one artifact and lying about the
# other twelve passed every gate. Two probes do not make that impossible -- only
# harder to write by accident -- and the real defence is that the probe paths are
# derived rather than fixed. S29 also requires the widest public interface, so
# first/middle/last perturbations cannot all land on `out0` of a tiny fixture.
widest_selftest_input="$(llzk_widest_public_input "${out_dir}")"
selftest_probes=("${selftest_inputs[0]}" "${selftest_inputs[${#selftest_inputs[@]}-1]}")
seen_selftest_inputs=()
for selftest_input in "${selftest_probes[@]}"; do
  duplicate=false
  for seen in "${seen_selftest_inputs[@]}"; do
    [[ "${seen}" == "${selftest_input}" ]] && duplicate=true
  done
  ${duplicate} && continue
  seen_selftest_inputs+=("${selftest_input}")
  selftest_name="$(basename -- "${selftest_input}" .0.inputs.json)"
  echo "-- on ${selftest_name}"
  require_llzk_witgen_discriminates \
    "${out_dir}/${selftest_name}.llzk" \
    "${selftest_input}" \
    "${out_dir}/${selftest_name}.0.expected.json" \
    "${out_dir}/${selftest_name}.0.public.json" \
    "${out_dir}"
  require_llzk_opt_discriminates "${out_dir}" "${out_dir}/${selftest_name}.llzk"
done

# Always run the widest probe in strict mode, even if it duplicates an endpoint:
# all three positions in both full-witness groups and the public group must be
# distinct keys rather than three copies of a one-field test.
selftest_name="$(basename -- "${widest_selftest_input}" .0.inputs.json)"
echo "-- widest interface: ${selftest_name}"
require_llzk_witgen_discriminates \
  "${out_dir}/${selftest_name}.llzk" \
  "${widest_selftest_input}" \
  "${out_dir}/${selftest_name}.0.expected.json" \
  "${out_dir}/${selftest_name}.0.public.json" \
  "${out_dir}" true
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
# Without an exact split, a change that put a felt.umod in every module could give
# smt_ok=0, smt_skipped=13 and still print PASS — the count is the only signal
# G10b produces. A floor also lets a new acceptance hide a new refusal. Pinning
# both aggregate totals exactly detects either unbalanced direction; a
# compensating per-artifact swap remains outside this count gate and must be
# reviewed from the named logs. These literals are deliberately not environment
# overrides: changing a count is a source diff (R4b-5, S29).
readonly LLZK_EXPECTED_SMT_OK=10
readonly LLZK_EXPECTED_SMT_SKIPPED=7
readonly LLZK_EXPECTED_ARTIFACTS=15
readonly LLZK_EXPECTED_VECTORS=51
readonly LLZK_EXPECTED_FIXTURES=2
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
  # `|| true` is load-bearing. Under `set -e` a command substitution that exits
  # non-zero in a bare assignment kills the shell *here*, so the message below --
  # the one that says a module failed for an undeclared reason, which is the
  # whole point of this branch -- could never print. R5d's D-8.
  reason="$(llzk_smt_declared_reason "${smt_log}" || true)"
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

  # G5/G6/G7 in two scopes per backend: --check-output compares llzk-witgen's
  # full witness and public interface against Clean's reference values. The
  # public-scope check is load-bearing: full-witness output includes both signal
  # and public members under `signals`, so it cannot detect a visibility change.
  inputs=("${out_dir}/${name}".*.inputs.json)
  (( ${#inputs[@]} > 0 )) \
    || fail "${name} has no input vectors; add some to LLZK.Corpus.corpus or the \
witness gates silently cover nothing"
  for input in "${inputs[@]}"; do
    index="${input##*/${name}.}"; index="${index%%.inputs.json}"
    expected="${out_dir}/${name}.${index}.expected.json"
    public_expected="${out_dir}/${name}.${index}.public.json"
    [[ -f "${expected}" ]] || fail "missing ${expected}"
    [[ -f "${public_expected}" ]] || fail "missing ${public_expected}"
    echo "-- G5/G7: interpreter vs Clean, vector ${index} (full witness + public)"
    "${LLZK_WITGEN}" "${artifact}" --inputs "${input}" \
      --output-scope=full-witness --check-output "${expected}" >/dev/null
    "${LLZK_WITGEN}" "${artifact}" --inputs "${input}" \
      --output-scope=public --check-output "${public_expected}" >/dev/null
    echo "-- G6/G7: execution engine vs Clean, vector ${index} (full witness + public)"
    "${LLZK_WITGEN}" "${artifact}" --inputs "${input}" --backend=execution-engine \
      --output-scope=full-witness --check-output "${expected}" >/dev/null
    "${LLZK_WITGEN}" "${artifact}" --inputs "${input}" --backend=execution-engine \
      --output-scope=public --check-output "${public_expected}" >/dev/null
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

llzk_require_exact_count "G10b modules lowered to SMT" \
  "${smt_ok}" "${LLZK_EXPECTED_SMT_OK}"

# G10b's own discriminate check. `--llzk-to-smt-no-cf` is the one pass with no
# separate self-test: a shim
# honest on --llzk-product-program and exiting 0 on the SMT flag would report
# every module lowered, and an acceptance-only count would *reward* it (R5d's
# D-3). The corpus contains modules the pass genuinely cannot lower -- anything
# with a felt.umod -- so a run in which it refused nothing means it is not
# running. Both directions observed, on real artifacts, every run.
llzk_require_exact_count "G10b modules skipped for declared reasons" \
  "${smt_skipped}" "${LLZK_EXPECTED_SMT_SKIPPED}"

# No silent shrinking. Every count below is reported in the PASS banner, and a
# banner that says "3 circuit(s)" after a change that dropped ten of them reads
# exactly like a pass (R5d's D-10).
llzk_require_exact_count "corpus artifacts" \
  "${#artifacts[@]}" "${LLZK_EXPECTED_ARTIFACTS}"
llzk_require_exact_count "corpus input vectors" \
  "${vectors}" "${LLZK_EXPECTED_VECTORS}"
llzk_require_exact_count "renderer fixtures" \
  "${#fixtures[@]}" "${LLZK_EXPECTED_FIXTURES}"

echo "PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12"
echo "  ${#artifacts[@]} circuit(s), ${vectors} input vector(s), both witgen backends,"
echo "  full-witness and public output scopes."
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
echo "preconditions of emission, so no module obtained through LLZK.compile or"
echo "LLZK.emit leaves this backend without them."
echo
echo "That is narrower than 'no module', and the difference is on screen above."
echo "The six Square_* entries are built from a hand-written Recognized with no"
echo "Clean circuit behind them, so there is nothing for G9 to compare against and"
echo "EmitMain reports them as none rather than as passing. G12 keeps the entry"
echo "points that skip G9 out of ordinary code. This banner used to say 'no module"
echo "leaves this backend without them', which was false for six of the eleven"
echo "modules the same run certifies (R5d)."
echo
echo "What remains beyond that is doc/llzk/GAPS.md -- above all D017, the reading"
echo "of LLZK's own semantics: that felt.add is +, constrain.in is membership, and"
echo "felt.umod reads its operands as canonical representatives. The @compute half"
echo "of that reading is what the ${vectors} vectors above test, on two independent"
echo "backends. The @constrain half has no executor in this toolchain and so no"
echo "empirical check at all. G10 shows the modules are admissible to LLZK's"
echo "analysis pipeline; it runs no solver."
