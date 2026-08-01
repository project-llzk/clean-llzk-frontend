#!/usr/bin/env bash
# Forbid the unchecked lookup-table path outside test modules.
#
# `Config`'s constructor is private. `Config.unsafeWithTables` is the only public
# way to put lookup tables into a configuration without a certificate, and
# `Config.ofCertified` is the wrapper that supplies one.
#
# R5's X1 was that the unchecked path was not merely available but *quiet*:
# `{ field := .babybear, tables := #[fatBytes] }` compiled Addition8FullCarry
# into a module admitting `w0 = 300`, which Clean's `ByteTable` rejects, with
# every gate green. The rows cannot be checked by the compiler — that is D012 —
# so the path cannot be deleted, and the negative fixtures need it. What it can
# be is loud and confined, which is what this enforces.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"

cd "${repo_root}"

# Where it is legitimate: the definition itself, the certified wrapper built on
# it, test modules, and prose.
allowed='^(Clean/Backend/LLZK/Basic\.lean|Clean/Backend/LLZK/TableCert\.lean|Clean/Backend/LLZK/Test/.*\.lean)$'

offenders=()
while IFS= read -r file; do
  [[ "${file}" =~ ${allowed} ]] || offenders+=("${file}")
done < <(grep -rl --include='*.lean' 'unsafeWithTables' Clean/ || true)

if (( ${#offenders[@]} > 0 )); then
  printf 'error: Config.unsafeWithTables outside a test module:\n' >&2
  printf '  %s\n' "${offenders[@]}" >&2
  llzk_fail "supply tables through Config.ofCertified, which requires an \
ExportTable.Certifies proof (TableCert.lean). If a table genuinely cannot be \
certified, that is a decision to record, not a call site to add."
fi

echo "unsafe-config check: no non-test module names Config.unsafeWithTables"
