#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
clean_base="1e563b9c27991b3795eb440c1ee0757edb4ce8b1"
expected_upstream="git@github.com:Verified-zkEVM/clean.git"
expected_toolchain="leanprover/lean4:v4.30.0"

cd "${repo_root}"

actual_upstream="$(git remote get-url upstream 2>/dev/null)" \
  || llzk_fail "no git remote named 'upstream'; this worktree is not the project home (D002)"
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

actual_toolchain="$(tr -d '\r\n' < lean-toolchain)"
if [[ "${actual_toolchain}" != "${expected_toolchain}" ]]; then
  echo "error: Lean toolchain is ${actual_toolchain}, expected ${expected_toolchain}" >&2
  exit 1
fi

echo "Clean base: ${clean_base}"
echo "HEAD:       $(git rev-parse HEAD)"
echo "upstream:   ${actual_upstream}"
echo "toolchain:  ${actual_toolchain}"
echo "pin check:  PASS"

