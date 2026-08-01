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

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"

"${script_dir}/check-pins.sh"

if ! command -v lake >/dev/null 2>&1; then
  echo "error: lake is not available" >&2
  exit 1
fi

echo "lake:       $(lake --version | head -n 1)"

# Under --require-llzk both tools must be present *and* report the pinned
# version. Without it, a missing tool is reported but tolerated, so the doctor is
# still useful before S01 has run.
for var in LLZK_OPT LLZK_WITGEN; do
  path="${!var:-}"
  if [[ "${require_llzk}" == true ]]; then
    require_llzk_tool "${var}" "${path}"
  elif [[ -n "${path}" && -x "${path}" ]]; then
    require_llzk_tool "${var}" "${path}"
  else
    echo "${var}: not provisioned (see doc/llzk/CURRENT.md)"
  fi
done

echo "doctor:     PASS"

