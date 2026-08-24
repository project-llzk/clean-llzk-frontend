#!/usr/bin/env bash
# Refuse mutable GitHub Action dependencies and accidental self-hosted execution.
set -euo pipefail

workflow_dir="${1:-.github/workflows}"
if [[ ! -d "${workflow_dir}" ]]; then
  echo "error: workflow directory does not exist: ${workflow_dir}" >&2
  exit 1
fi
if ! command -v grep >/dev/null 2>&1; then
  echo "error: required command not found: grep" >&2
  exit 1
fi
if ! command -v sha256sum >/dev/null 2>&1; then
  echo "error: required command not found: sha256sum" >&2
  exit 1
fi

# The exact 2026-08-24 ubuntu-24.04 publication run did not provide ripgrep.
# Keep this early policy gate on the runner's baseline grep interface instead
# of adding another CI bootstrap/input. Every pattern below is explicit ERE or
# fixed-string matching, and C locale keeps the ASCII YAML character classes
# deterministic.
export LC_ALL=C

# The generic checks below deliberately remain small line-oriented tripwires;
# they are not a YAML parser. For the load-bearing repository invocation, bind
# them to the exact reviewed workflow path set and bytes first. A workflow
# grammar trick, permission/step relationship change, hidden/nested addition,
# rename, symlink, or ordinary edit must therefore update this manifest in the
# checker itself and receive the same code review as the policy.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/../.." && pwd -P)"
repo_workflow_dir="$(cd -- "${repo_root}/.github/workflows" && pwd -P)"
checked_workflow_dir="$(cd -- "${workflow_dir}" && pwd -P)"

check_repository_workflow_manifest() {
  local candidate rel hash_line actual_hash expected_hash
  local status=0
  local seen_bench_command=0 seen_bench_main=0 seen_bench=0 seen_ci=0

  shopt -s dotglob globstar nullglob
  for candidate in "${workflow_dir}"/**; do
    case "${candidate}" in
      *.yml|*.yaml) ;;
      *) continue ;;
    esac
    rel="${candidate#"${workflow_dir}"/}"
    if [[ -L "${candidate}" || ! -f "${candidate}" ]]; then
      echo "error: workflow manifest mismatch: nonregular path '${rel}'" >&2
      status=1
      continue
    fi
    case "${rel}" in
      bench-command.yml)
        expected_hash=eb2994c0f0c914d368bd006b663f11401b033b9f4a7b7d73b02729d4aefed29f
        seen_bench_command=1 ;;
      bench-main.yml)
        expected_hash=6485c6359e5e57875afe5d6fe498a805c7b3200517629a6abbdbb58e2b8be9fc
        seen_bench_main=1 ;;
      bench.yml)
        expected_hash=32041bf71398add49a5bad144c821c80592f85747301fa054ae73176d55843fa
        seen_bench=1 ;;
      ci.yml)
        expected_hash=5bbccdb4b6da9cb5c3522d07e5b988f10ebcbc11c094915ef28b9f95346af9ef
        seen_ci=1 ;;
      *)
        echo "error: workflow manifest mismatch: unexpected path '${rel}'" >&2
        status=1
        continue ;;
    esac
    hash_line="$(sha256sum -- "${candidate}")" || {
      echo "error: workflow manifest mismatch: cannot hash '${rel}'" >&2
      status=1
      continue
    }
    actual_hash="${hash_line%%[[:space:]]*}"
    if [[ "${actual_hash}" != "${expected_hash}" ]]; then
      echo "error: workflow manifest mismatch: content changed for '${rel}'" >&2
      status=1
    fi
  done
  shopt -u dotglob globstar nullglob

  (( seen_bench_command == 1 )) || {
    echo "error: workflow manifest mismatch: missing path 'bench-command.yml'" >&2
    status=1
  }
  (( seen_bench_main == 1 )) || {
    echo "error: workflow manifest mismatch: missing path 'bench-main.yml'" >&2
    status=1
  }
  (( seen_bench == 1 )) || {
    echo "error: workflow manifest mismatch: missing path 'bench.yml'" >&2
    status=1
  }
  (( seen_ci == 1 )) || {
    echo "error: workflow manifest mismatch: missing path 'ci.yml'" >&2
    status=1
  }
  return "${status}"
}

if [[ "${checked_workflow_dir}" == "${repo_workflow_dir}" ]]; then
  check_repository_workflow_manifest || exit 1
fi

# Mirror ripgrep's recursive directory scan without parsing filenames out of
# `file:line:text` records. Keeping the filename in the outer loop makes spaces
# and colons harmless. Dot-prefixed paths are included because GitHub accepts a
# dot-prefixed `.yml`/`.yaml` workflow filename. Symlinks are not followed.
workflow_files=()
shopt -s dotglob globstar nullglob
for candidate in "${workflow_dir}"/**; do
  [[ -f "${candidate}" && ! -L "${candidate}" ]] \
    && workflow_files+=("${candidate}")
done
shopt -u dotglob globstar nullglob

# Print every matching line as `line:text`. No match is an empty successful
# scan; a read or matcher error is fatal rather than becoming a false "none".
grep_ere_lines() {
  local pattern="$1" file="$2" status=0
  grep -anE -- "${pattern}" "${file}" || status=$?
  case "${status}" in
    0|1) return 0 ;;
    *) echo "error: grep failed while scanning ${file}" >&2; return "${status}" ;;
  esac
}

# Predicate form with the same fail-closed distinction between no match (1)
# and an actual grep/read failure (>1).
grep_ere_has() {
  local pattern="$1" file="$2" status=0
  grep -aEq -- "${pattern}" "${file}" || status=$?
  case "${status}" in
    0) return 0 ;;
    1) return 1 ;;
    *) echo "error: grep failed while scanning ${file}" >&2; exit "${status}" ;;
  esac
}

failed=0
references=0
for file in "${workflow_files[@]}"; do
  action_lines="$(grep_ere_lines \
    '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*[^[:space:]#]+' "${file}")" \
    || exit 1
  while IFS=: read -r line source; do
    [[ -n "${line}" ]] || continue
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
  done <<<"${action_lines}"
done

if (( references == 0 )); then
  echo "error: no action references found under ${workflow_dir}" >&2
  failed=$(( failed + 1 ))
fi

require_benchmark_opt_in() {
  local workflow="$1"
  if ! grep_ere_has "^[[:space:]]+vars\.CLEAN_BENCH_ENABLED == 'true'|^[[:space:]]+if: vars\.CLEAN_BENCH_ENABLED == 'true'" \
    "${workflow}"; then
    echo "error: ${workflow}: benchmark entry point is not opt-in gated by CLEAN_BENCH_ENABLED" >&2
    failed=$(( failed + 1 ))
  fi
}

for workflow in "${workflow_files[@]}"; do
  case "$(basename "${workflow}")" in
    bench*.yml|bench*.yaml) require_benchmark_opt_in "${workflow}"; continue ;;
  esac
  grep_ere_has 'self-hosted' "${workflow}" \
    && require_benchmark_opt_in "${workflow}"
done

for file in "${workflow_files[@]}"; do
  runner_lines="$(grep_ere_lines 'runs-on:[[:space:]]*ubuntu-latest' "${file}")" \
    || exit 1
  while IFS=: read -r line _; do
    [[ -n "${line}" ]] || continue
    echo "error: ${file}:${line}: moving hosted runner label 'ubuntu-latest'; pin an Ubuntu release" >&2
    failed=$(( failed + 1 ))
  done <<<"${runner_lines}"
done

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
  if grep_ere_has 'uses:[[:space:]]*cachix/install-nix-action@' "${ci}"; then
    if ! grep_ere_has '^            extra-substituters = https://veridise-public\.cachix\.org$' "${ci}" \
      || ! grep_ere_has '^            extra-trusted-public-keys = veridise-public\.cachix\.org-1:FvpZ8GzAj1mmJA5PnO9UgKxC6CQdmPutuIKtEpGmeig=$' "${ci}" \
      || ! grep_ere_has '--max-jobs[[:space:]]+0' "${ci}"; then
      echo "error: ${ci}: LLZK Nix build is not locked to the trusted public substituter with source builds disabled" >&2
      failed=$(( failed + 1 ))
    fi
  fi
fi

for workflow in "${workflow_files[@]}"; do
  grep_ere_has 'uses:[[:space:]]*dtolnay/rust-toolchain@' "${workflow}" || continue
  if ! grep_ere_has '^[[:space:]]+toolchain:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*$' "${workflow}"; then
    echo "error: ${workflow}: dtolnay/rust-toolchain does not request a fixed Rust release" >&2
    failed=$(( failed + 1 ))
  fi
done

if (( failed > 0 )); then
  exit 1
fi
echo "action pin check: PASS (${references} immutable action reference(s))"
