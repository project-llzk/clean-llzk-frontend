#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"
clean_base="0e53b9f2d05f06defa2aa0a859f549b611583f10"
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

if ! git cat-file -e "${clean_base}^{commit}" 2>/dev/null; then
  echo "error: pinned Clean base is missing: ${clean_base}" >&2
  exit 1
fi

if ! git merge-base --is-ancestor "${clean_base}" HEAD; then
  echo "error: HEAD does not descend from pinned Clean base ${clean_base}" >&2
  exit 1
fi

# This branch changes Clean's core in exactly two places, and several decisions
# rest on that: D012's follow-up defers naming ByteTable's `StaticTable` because
# "that belongs to a Clean-side session", and GAPS.md item 8 defers removing
# `Clean/Utils/Primes.lean`'s `native_decide` uses because "that file is Clean
# core, which this branch keeps byte-identical to the pinned base". Both are
# arguments about *where* work belongs, and both stop holding the moment the
# premise does.
#
# R6 found the premise was true and gated nowhere -- an invariant three documents
# rely on, checkable in one line, checked by nobody. The two exceptions are the
# registration edits a backend has to make: `Clean.lean` imports it and
# `Clean/Test.lean` imports its test modules.
core_changes="$(git diff --name-only "${clean_base}" HEAD -- Clean/ \
  ':!Clean/Backend/LLZK' ':!Clean.lean' ':!Clean/Test.lean')"
if [[ -n "${core_changes}" ]]; then
  echo "error: Clean's core is no longer byte-identical to the pinned base ${clean_base}:" >&2
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

echo "Clean base: ${clean_base}"
echo "core:       byte-identical outside Clean/Backend/LLZK (plus the two registration files)"
echo "HEAD:       $(git rev-parse HEAD)"
echo "upstream:   ${actual_upstream}"
echo "toolchain:  ${actual_toolchain}"
echo "pin check:  PASS"
