#!/usr/bin/env bash
# Refuse mutable GitHub Action dependencies and accidental self-hosted execution.
set -euo pipefail

workflow_dir="${1:-.github/workflows}"
if [[ ! -d "${workflow_dir}" ]]; then
  echo "error: workflow directory does not exist: ${workflow_dir}" >&2
  exit 1
fi

failed=0
references=0
while IFS=: read -r file line source; do
  [[ -n "${file}" ]] || continue
  target="$(sed -E 's/.*uses:[[:space:]]*([^[:space:]#]+).*/\1/' <<<"${source}")"
  references=$(( references + 1 ))
  case "${target}" in
    ./*) continue ;;
    docker://*@sha256:*) continue ;;
  esac
  if [[ ! "${target}" =~ ^[^@[:space:]]+@[0-9a-f]{40}$ ]]; then
    echo "error: ${file}:${line}: mutable action reference '${target}'; pin a 40-character commit SHA" >&2
    failed=$(( failed + 1 ))
  fi
done < <(rg -n --no-heading '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*[^[:space:]#]+' \
  "${workflow_dir}" || true)

if (( references == 0 )); then
  echo "error: no action references found under ${workflow_dir}" >&2
  failed=$(( failed + 1 ))
fi

require_benchmark_opt_in() {
  local workflow="$1"
  if ! rg -q "^[[:space:]]+vars\.CLEAN_BENCH_ENABLED == 'true'|^[[:space:]]+if: vars\.CLEAN_BENCH_ENABLED == 'true'" \
    "${workflow}"; then
    echo "error: ${workflow}: benchmark entry point is not opt-in gated by CLEAN_BENCH_ENABLED" >&2
    failed=$(( failed + 1 ))
  fi
}

shopt -s nullglob
for workflow in "${workflow_dir}"/bench*.yml "${workflow_dir}"/bench*.yaml; do
  require_benchmark_opt_in "${workflow}"
done
shopt -u nullglob

while IFS= read -r workflow; do
  case "$(basename "${workflow}")" in
    bench*.yml|bench*.yaml) continue ;;
  esac
  require_benchmark_opt_in "${workflow}"
done < <(rg -l 'self-hosted' "${workflow_dir}" || true)

while IFS=: read -r file line _; do
  echo "error: ${file}:${line}: moving hosted runner label 'ubuntu-latest'; pin an Ubuntu release" >&2
  failed=$(( failed + 1 ))
done < <(rg -n --no-heading 'runs-on:[[:space:]]*ubuntu-latest' "${workflow_dir}" || true)

ci="${workflow_dir}/ci.yml"
if [[ -f "${ci}" ]]; then
  if ! awk '
    $0 == "permissions:" { in_permissions = 1; next }
    in_permissions && /^[^ ]/ { in_permissions = 0 }
    in_permissions && $0 == "  contents: read" { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "${ci}"; then
    echo "error: ${ci}: workflow-level token permissions are not explicitly read-only" >&2
    failed=$(( failed + 1 ))
  fi
  if rg -q 'uses:[[:space:]]*cachix/install-nix-action@' "${ci}"; then
    if ! rg -q '^            extra-substituters = https://veridise-public\.cachix\.org$' "${ci}" \
      || ! rg -q '^            extra-trusted-public-keys = veridise-public\.cachix\.org-1:FvpZ8GzAj1mmJA5PnO9UgKxC6CQdmPutuIKtEpGmeig=$' "${ci}" \
      || ! rg -q -- '--max-jobs[[:space:]]+0' "${ci}"; then
      echo "error: ${ci}: LLZK Nix build is not locked to the trusted public substituter with source builds disabled" >&2
      failed=$(( failed + 1 ))
    fi
  fi
fi

while IFS= read -r workflow; do
  if ! rg -q '^[[:space:]]+toolchain:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*$' "${workflow}"; then
    echo "error: ${workflow}: dtolnay/rust-toolchain does not request a fixed Rust release" >&2
    failed=$(( failed + 1 ))
  fi
done < <(rg -l 'uses:[[:space:]]*dtolnay/rust-toolchain@' "${workflow_dir}" || true)

if (( failed > 0 )); then
  exit 1
fi
echo "action pin check: PASS (${references} immutable action reference(s))"
