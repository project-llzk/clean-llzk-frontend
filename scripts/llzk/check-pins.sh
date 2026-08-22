#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"
clean_upstream_base="0e53b9f2d05f06defa2aa0a859f549b611583f10"
clean_base="3d086f32a71d17cbddfb46c0dea63cd36c8aa552"
expected_upstream="git@github.com:Verified-zkEVM/clean.git"
expected_toolchain="leanprover/lean4:v4.32.2"

cd "${repo_root}"

actual_upstream="$(git remote get-url upstream 2>/dev/null)" \
  || llzk_fail "no git remote named 'upstream'; this worktree is not the project home (D002).
A fresh clone has only 'origin'. If this is a checkout of the project, add it:
  git remote add upstream ${expected_upstream}
S24 found this said what was wrong and not what to do; see
doc/llzk/evidence/S24/clean-checkout.md."
if [[ "${actual_upstream}" != "${expected_upstream}" ]]; then
  echo "error: upstream is ${actual_upstream}, expected ${expected_upstream}" >&2
  exit 1
fi

if ! git cat-file -e "${clean_upstream_base}^{commit}" 2>/dev/null; then
  echo "error: pinned upstream Clean base is missing: ${clean_upstream_base}" >&2
  exit 1
fi

if ! git cat-file -e "${clean_base}^{commit}" 2>/dev/null; then
  echo "error: pinned Clean overlay is missing: ${clean_base}" >&2
  exit 1
fi

if ! git merge-base --is-ancestor "${clean_upstream_base}" "${clean_base}"; then
  echo "error: pinned Clean overlay ${clean_base} does not descend from" >&2
  echo "  pinned upstream Clean base ${clean_upstream_base}" >&2
  exit 1
fi

overlay_parents="$(git rev-list --parents -1 "${clean_base}")"
if [[ "${overlay_parents}" != "${clean_base} ${clean_upstream_base}" ]]; then
  echo "error: pinned Clean overlay ${clean_base} is not a direct single-parent child of" >&2
  echo "  the pinned upstream Clean base ${clean_upstream_base}" >&2
  exit 1
fi

overlay_delta="$(git diff --name-status "${clean_upstream_base}" "${clean_base}")"
expected_overlay_delta=$'M\tClean/Gadgets/Xor/Xor32.lean'
if [[ "${overlay_delta}" != "${expected_overlay_delta}" ]]; then
  echo "error: pinned Clean overlay differs from the reviewed one-path delta:" >&2
  sed 's/^/  /' <<<"${overlay_delta}" >&2
  echo "  expected: M  Clean/Gadgets/Xor/Xor32.lean" >&2
  exit 1
fi

if ! git merge-base --is-ancestor "${clean_base}" HEAD; then
  echo "error: HEAD does not descend from pinned Clean overlay ${clean_base}" >&2
  exit 1
fi

# D035 adopts one reviewed Clean-side overlay commit for executable Xor32 byte
# narrowing. The exact U..K delta is checked above. From K onward, this branch
# changes Clean's core in exactly two registration places, and several decisions
# still rely on that confinement.
#
# R6 found the premise was true and gated nowhere -- an invariant three documents
# rely on, checkable in one line, checked by nobody. The two exceptions are the
# registration edits a backend has to make: `Clean.lean` imports it and
# `Clean/Test.lean` imports its test modules.
core_changes="$(git diff --name-only "${clean_base}" HEAD -- Clean/ \
  ':!Clean/Backend/LLZK' ':!Clean.lean' ':!Clean/Test.lean')"
if [[ -n "${core_changes}" ]]; then
  echo "error: Clean's core is no longer byte-identical to the accepted overlay ${clean_base}:" >&2
  sed 's/^/  /' <<<"${core_changes}" >&2
  echo "  This branch is allowed to add Clean/Backend/LLZK/ and to register it in" >&2
  echo "  Clean.lean and Clean/Test.lean, and nothing else. A change to Clean's core" >&2
  echo "  belongs to a Clean-side session with its own review (D012, ORCHESTRATION §11)," >&2
  echo "  and several decisions cite this invariant by name." >&2
  exit 1
fi

# The diff above compares two *commits* -- but G1 builds and G2 emits from the
# working tree. R7 demonstrated the gap: an uncommitted edit to
# Clean/Utils/Primes.lean reported "byte-identical PASS" while being exactly
# what got built, emitted, and certified, and G9 cannot catch it because both
# of its sides move together (R7-01). So the same pathspec is checked against
# the working tree too, staged or not.
dirty_core="$(git status --porcelain -- Clean/ \
  ':!Clean/Backend/LLZK' ':!Clean.lean' ':!Clean/Test.lean')"
if [[ -n "${dirty_core}" ]]; then
  echo "error: Clean's core has uncommitted changes; the tree that would be" >&2
  echo "  built is not the tree the byte-identity check above certified (R7-01):" >&2
  sed 's/^/  /' <<<"${dirty_core}" >&2
  echo "  Commit to Clean/Backend/LLZK/ only, or restore these files." >&2
  exit 1
fi

actual_toolchain="$(tr -d '\r\n' < lean-toolchain)"
if [[ "${actual_toolchain}" != "${expected_toolchain}" ]]; then
  echo "error: Lean toolchain is ${actual_toolchain}, expected ${expected_toolchain}" >&2
  exit 1
fi

echo "Clean upstream: ${clean_upstream_base}"
echo "Clean overlay:  ${clean_base}"
echo "overlay:        exact reviewed Xor32 delta"
echo "core after K:   byte-identical outside Clean/Backend/LLZK (plus the two registration files)"
echo "HEAD:       $(git rev-parse HEAD)"
echo "upstream:   ${actual_upstream}"
echo "toolchain:  ${actual_toolchain}"
echo "pin check:  PASS"
