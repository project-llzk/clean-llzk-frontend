#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
require_llzk=false

if [[ "${1:-}" == "--require-llzk" ]]; then
  require_llzk=true
elif [[ "$#" -ne 0 ]]; then
  echo "usage: $0 [--require-llzk]" >&2
  exit 2
fi

"${script_dir}/check-pins.sh"

if ! command -v lake >/dev/null 2>&1; then
  echo "error: lake is not available" >&2
  exit 1
fi

echo "lake:       $(lake --version | head -n 1)"

llzk_opt="${LLZK_OPT:-}"
llzk_witgen="${LLZK_WITGEN:-}"

if [[ -n "${llzk_opt}" && -x "${llzk_opt}" ]]; then
  echo "llzk-opt:   ${llzk_opt}"
else
  echo "llzk-opt:   pending S01"
  if [[ "${require_llzk}" == true ]]; then
    echo "error: set LLZK_OPT to the pinned LLZK 3.0 binary" >&2
    exit 1
  fi
fi

if [[ -n "${llzk_witgen}" && -x "${llzk_witgen}" ]]; then
  echo "llzk-witgen:${llzk_witgen}"
else
  echo "llzk-witgen: pending S01"
  if [[ "${require_llzk}" == true ]]; then
    echo "error: set LLZK_WITGEN to the pinned LLZK 3.0 binary" >&2
    exit 1
  fi
fi

echo "doctor:     PASS"

