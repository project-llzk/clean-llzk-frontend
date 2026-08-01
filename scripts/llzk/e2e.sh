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
require_llzk_tool LLZK_OPT "${LLZK_OPT:-}"
require_llzk_tool LLZK_WITGEN "${LLZK_WITGEN:-}"
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

for artifact in "${artifacts[@]}"; do
  echo "== ${artifact##*/} =="
  echo "-- G3: parse and verify"
  "${LLZK_OPT}" "${artifact}" -o /dev/null
  echo "-- G4: round trip"
  "${LLZK_OPT}" --verify-roundtrip "${artifact}" -o /dev/null
  echo "   ok"
done
echo

echo "All gates that do not need per-circuit input vectors passed."
echo "G5, G6 and G7 need an input corpus and a Clean-side witness comparison;"
echo "they are not implemented yet, and this script does not claim them."
