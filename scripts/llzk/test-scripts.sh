#!/usr/bin/env bash
# Error-path tests for the Clean → LLZK shell harness.
#
# Why this exists. Every gate this project has is enforced by these scripts, and
# until now nothing exercised any of their *failure* branches — only the happy
# path, on every run. That gap shipped a broken fix: R4 found `check-pins.sh`
# died on git's own message when a clone had no `upstream` remote, the repair
# added `llzk_fail "no git remote named 'upstream'..."`, and the repair itself
# was wrong — `check-pins.sh` never sourced `lib.sh`, so the branch died with
# `llzk_fail: command not found` and exit 127 instead of the message it was
# written to print. It failed closed, so no gate ever noticed, and it survived
# both R4's verification and R5's bootstrap.
#
# The lesson is not "add a source line". It is that a check nothing can observe
# failing is not a check. Each case below asserts a specific exit status *and* a
# specific message, so a branch that stops working the way this one did turns
# this script red.
#
# Deliberately does not invoke `e2e.sh`: that would need the LLZK tools and a
# Lean build. `lib.sh`'s helpers are called directly, and `check-pins.sh` is
# driven against throwaway clones, so this runs in about a second with no
# external dependency beyond git.
set -uo pipefail   # not -e: this script runs commands that are meant to fail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

passed=0
failed=0

# expect NAME EXPECTED_STATUS EXPECTED_SUBSTRING -- COMMAND...
#
# Runs COMMAND, then asserts both its exit status and that its combined output
# contains EXPECTED_SUBSTRING. Asserting the message and not only the status is
# the point: the defect that motivated this script exited non-zero and would
# have passed a status-only assertion.
expect() {
  local name="$1" want_status="$2" want_text="$3"; shift 4
  local out status
  out="$("$@" 2>&1)"; status=$?
  if [[ "${status}" -ne "${want_status}" ]]; then
    echo "FAIL ${name}: exit ${status}, expected ${want_status}"
    echo "${out}" | sed 's/^/       /'
    failed=$(( failed + 1 )); return
  fi
  if [[ "${want_text}" != "" && "${out}" != *"${want_text}"* ]]; then
    echo "FAIL ${name}: output did not contain '${want_text}'"
    echo "${out}" | sed 's/^/       /'
    failed=$(( failed + 1 )); return
  fi
  echo "ok   ${name}"
  passed=$(( passed + 1 ))
}

# A throwaway clone of this repository, so the pinned base commit is present and
# only the property under test differs. `--shared` keeps it near-instant.
#
# The clone's scripts are then overwritten with the *working tree's*, so this
# tests the scripts as they are now rather than as they were last committed. The
# first version of this file got that backwards and reported a failure for a
# defect that had already been fixed in the tree.
make_clone() {
  local name="$1" dir="${workdir}/$1"
  git clone --quiet --shared --no-checkout "${repo_root}" "${dir}" 2>/dev/null
  git -C "${dir}" checkout --quiet "$(git -C "${repo_root}" rev-parse HEAD)" 2>/dev/null
  cp "${script_dir}"/*.sh "${dir}/scripts/llzk/"
  echo "${dir}"
}

echo "== check-pins.sh =="

# The defect this script was written for. A clone has `origin` but no
# `upstream`, which is exactly the state a fresh reviewer's checkout is in.
clone="$(make_clone no-upstream)"
expect "no upstream remote" 1 "no git remote named 'upstream'" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone wrong-upstream)"
git -C "${clone}" remote add upstream https://example.invalid/not-clean.git
expect "wrong upstream URL" 1 "expected git@github.com:Verified-zkEVM/clean.git" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

# A repository that does not contain the pinned Clean base at all.
orphan="${workdir}/no-base"
mkdir -p "${orphan}/scripts/llzk"
cp "${script_dir}"/{check-pins.sh,lib.sh} "${orphan}/scripts/llzk/"
cp "${repo_root}/lean-toolchain" "${orphan}/"
git -C "${orphan}" init --quiet .
git -C "${orphan}" remote add upstream git@github.com:Verified-zkEVM/clean.git
git -C "${orphan}" -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m base
expect "pinned base absent" 1 "pinned Clean base is missing" \
  -- bash "${orphan}/scripts/llzk/check-pins.sh"

# A history that exists but does not descend from the pinned base.
clone="$(make_clone orphan-head)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
git -C "${clone}" checkout --quiet --orphan detached
git -C "${clone}" -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m unrelated
expect "HEAD not descended from base" 1 "does not descend from pinned Clean base" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone bad-toolchain)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
echo "leanprover/lean4:v4.99.0" > "${clone}/lean-toolchain"
expect "toolchain mismatch" 1 "Lean toolchain is leanprover/lean4:v4.99.0" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone happy)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
expect "happy path" 0 "pin check:  PASS" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

echo
echo "== lib.sh tool checks =="

# Each helper is called in a subshell so its `exit 1` is observable.
run_helper() { ( set -uo pipefail; source "${script_dir}/lib.sh"; "$@" ); }

expect "LLZK_OPT unset" 1 "LLZK_OPT is not set" \
  -- run_helper require_llzk_executable LLZK_OPT ""

echo "not executable" > "${workdir}/not-exec"
expect "tool not executable" 1 "is not an executable" \
  -- run_helper require_llzk_executable LLZK_OPT "${workdir}/not-exec"

# A shim that answers --version with the wrong LLZK version. This is the check
# that keeps the LLZK 2.0 binary installed on this machine from satisfying the
# harness.
mkdir -p "${workdir}/shim"
cat > "${workdir}/shim/llzk-opt" <<'SHIM'
#!/usr/bin/env bash
echo "LLZK version 2.0.0"
SHIM
chmod +x "${workdir}/shim/llzk-opt"
expect "wrong LLZK version" 1 "does not report LLZK version 3.0.0" \
  -- run_helper require_llzk_version LLZK_OPT "${workdir}/shim/llzk-opt"

cat > "${workdir}/shim/llzk-right" <<'SHIM'
#!/usr/bin/env bash
echo "LLZK version 3.0.0"
SHIM
chmod +x "${workdir}/shim/llzk-right"
expect "right LLZK version" 0 "LLZK version 3.0.0" \
  -- run_helper require_llzk_version LLZK_OPT "${workdir}/shim/llzk-right"

mkdir -p "${workdir}/elsewhere"
touch "${workdir}/elsewhere/llzk-witgen"; chmod +x "${workdir}/elsewhere/llzk-witgen"
expect "witgen from another install" 1 "is not in the same directory" \
  -- run_helper require_llzk_sibling \
       LLZK_WITGEN "${workdir}/elsewhere/llzk-witgen" \
       LLZK_OPT "${workdir}/shim/llzk-right"

echo
echo "== lib.sh discriminate self-tests =="

# These are the checks that keep every other green honest (R2-06, R4b-2). Their
# *positive* direction runs on the real tools every time e2e.sh runs; nothing
# exercised their negative direction, which is the direction that matters.

# An llzk-opt that answers --version and accepts anything, including a file that
# is not MLIR — the exact shim that made G3, G4 and G10 vacuous.
cat > "${workdir}/shim/llzk-opt-permissive" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in --version) echo "LLZK version 3.0.0";; esac
exit 0
SHIM
chmod +x "${workdir}/shim/llzk-opt-permissive"
printf 'module attributes {llzk.lang} {}\n' > "${workdir}/dummy.llzk"
expect "llzk-opt self-test catches a permissive shim" 1 "accepted a file that is not MLIR" \
  -- env LLZK_OPT="${workdir}/shim/llzk-opt-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_opt_discriminates "$2" "$3"' \
       _ "${script_dir}" "${workdir}" "${workdir}/dummy.llzk"

# An llzk-witgen that exits 0 unconditionally, so --check-output never fails.
cat > "${workdir}/shim/llzk-witgen-permissive" <<'SHIM'
#!/usr/bin/env bash
exit 0
SHIM
chmod +x "${workdir}/shim/llzk-witgen-permissive"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1"}}\n' > "${workdir}/expected.json"
printf '{"arg0":1}\n' > "${workdir}/inputs.json"
expect "llzk-witgen self-test catches a permissive shim" 1 "is not checking anything" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected.json" "${workdir}"

echo
if (( failed > 0 )); then
  echo "FAIL: ${passed} passed, ${failed} failed"
  exit 1
fi
echo "PASS: ${passed} error paths exercised"
