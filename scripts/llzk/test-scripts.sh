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
  cp "${script_dir}"/*.sh "${script_dir}"/*.py "${dir}/scripts/llzk/"
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

# A repository that does not contain the pinned upstream Clean base at all.
orphan="${workdir}/no-base"
mkdir -p "${orphan}/scripts/llzk"
cp "${script_dir}"/{check-pins.sh,lib.sh} "${orphan}/scripts/llzk/"
cp "${repo_root}/lean-toolchain" "${orphan}/"
git -C "${orphan}" init --quiet .
git -C "${orphan}" remote add upstream git@github.com:Verified-zkEVM/clean.git
git -C "${orphan}" -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m base
expect "pinned upstream base absent" 1 "pinned upstream Clean base is missing" \
  -- bash "${orphan}/scripts/llzk/check-pins.sh"

clone="$(make_clone no-overlay)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
sed -i 's/^clean_base=.*/clean_base="0000000000000000000000000000000000000000"/' \
  "${clone}/scripts/llzk/check-pins.sh"
expect "pinned Clean overlay absent" 1 "pinned Clean overlay is missing" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone unrelated-overlay)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
sed -i 's/^clean_base=.*/clean_base="97390faca9dd0680b7fe3a6db26f4de0c3cf6a06"/' \
  "${clone}/scripts/llzk/check-pins.sh"
expect "Clean overlay unrelated to upstream base" 1 "does not descend from" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone indirect-overlay)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
sed -i 's/^clean_base=.*/clean_base="9b46264c59ed69af24817cb4b2cfdb7ebcfb4629"/' \
  "${clone}/scripts/llzk/check-pins.sh"
expect "Clean overlay is not a direct child" 1 "not a direct single-parent child" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone wrong-overlay-delta)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
original_head="$(git -C "${clone}" rev-parse HEAD)"
git -C "${clone}" checkout --quiet --detach 0e53b9f2d05f06defa2aa0a859f549b611583f10
echo "-- wrong overlay path" >> "${clone}/Clean/Utils/Primes.lean"
git -C "${clone}" -c user.email=t@t -c user.name=t commit --quiet -am "wrong overlay"
wrong_overlay="$(git -C "${clone}" rev-parse HEAD)"
git -C "${clone}" checkout --quiet "${original_head}"
sed -i "s/^clean_base=.*/clean_base=\"${wrong_overlay}\"/" \
  "${clone}/scripts/llzk/check-pins.sh"
expect "unexpected Clean overlay delta" 1 "differs from the reviewed one-path delta" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

# A history that exists but does not descend from the pinned overlay.
clone="$(make_clone orphan-head)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
git -C "${clone}" checkout --quiet --orphan detached
git -C "${clone}" -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m unrelated
expect "HEAD not descended from overlay" 1 "does not descend from pinned Clean overlay" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone bad-toolchain)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
echo "leanprover/lean4:v4.99.0" > "${clone}/lean-toolchain"
expect "toolchain mismatch" 1 "Lean toolchain is leanprover/lean4:v4.99.0" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

# R6. The invariant D012 and GAPS item 8 both argue from, gated for the first
# time. Committed in the clone, because check-pins.sh compares HEAD against the
# base rather than the worktree.
clone="$(make_clone core-drift)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
echo "-- touched by a backend session" >> "${clone}/Clean/Utils/Primes.lean"
git -C "${clone}" -c user.email=t@t -c user.name=t commit --quiet -am "touch Clean core"
expect "a change to Clean's core is caught" 1 "no longer byte-identical to the accepted overlay" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

# R7-01. The commit-vs-commit diff above is blind to the working tree, which is
# what G1 builds and G2 emits from: an *uncommitted* core edit reported
# "byte-identical PASS" while being exactly what got built and certified, and
# G9 cannot see it because both of its sides move together.
clone="$(make_clone core-dirty)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
echo "-- uncommitted working-tree edit" >> "${clone}/Clean/Utils/Primes.lean"
expect "an uncommitted change to Clean's core is caught" 1 "uncommitted changes" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone happy)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
expect "happy path" 0 "pin check:  PASS" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

echo
echo "== check-actions-pinned.sh =="

mkdir -p "${workdir}/actions-mutable"
cat > "${workdir}/actions-mutable/ci.yml" <<'YAML'
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
YAML
expect "a mutable action tag is caught" 1 "mutable action reference" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-mutable"

mkdir -p "${workdir}/actions-pinned"
cat > "${workdir}/actions-pinned/ci.yml" <<'YAML'
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
      - uses: ./local-action
YAML
expect "immutable and local actions are accepted" 0 "2 immutable action reference" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-pinned"

mkdir -p "${workdir}/actions-moving-runner"
cat > "${workdir}/actions-moving-runner/ci.yml" <<'YAML'
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
YAML
expect "a moving hosted runner label is caught" 1 "moving hosted runner label" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-moving-runner"

mkdir -p "${workdir}/actions-self-hosted"
cat > "${workdir}/actions-self-hosted/bench.yml" <<'YAML'
jobs:
  bench:
    runs-on: [self-hosted, linux]
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
YAML
expect "an implicit self-hosted job is caught" 1 "not opt-in gated" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-self-hosted"

mkdir -p "${workdir}/actions-self-hosted-gated"
cat > "${workdir}/actions-self-hosted-gated/bench.yml" <<'YAML'
jobs:
  bench:
    if: vars.CLEAN_BENCH_ENABLED == 'true'
    runs-on: [self-hosted, linux]
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
YAML
expect "an explicitly gated self-hosted job is accepted" 0 "1 immutable action reference" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-self-hosted-gated"

mkdir -p "${workdir}/actions-hosted-bench"
cat > "${workdir}/actions-hosted-bench/bench-command.yml" <<'YAML'
permissions:
  contents: read
jobs:
  dispatch:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
YAML
expect "a hosted benchmark entry point also requires opt-in" 1 "benchmark entry point is not opt-in gated" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-hosted-bench"

mkdir -p "${workdir}/actions-token-write"
cat > "${workdir}/actions-token-write/ci.yml" <<'YAML'
permissions:
  contents: write
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
YAML
expect "a non-read-only workflow token is caught" 1 "workflow-level token permissions are not explicitly read-only" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-token-write"

mkdir -p "${workdir}/actions-moving-rust"
cat > "${workdir}/actions-moving-rust/ci.yml" <<'YAML'
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: dtolnay/rust-toolchain@4360b52568e2003a75bf9bc1d59f33a8e3fc893c
YAML
expect "a moving Rust toolchain is caught" 1 "does not request a fixed Rust release" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-moving-rust"

mkdir -p "${workdir}/actions-untrusted-nix"
cat > "${workdir}/actions-untrusted-nix/ci.yml" <<'YAML'
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: cachix/install-nix-action@ba0dd844c9180cbf77aa72a116d6fbc515d0e87b
      - run: nix build --no-link example#package
YAML
expect "an LLZK CI build without the trusted binary-cache boundary is caught" 1 "not locked to the trusted public substituter" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${workdir}/actions-untrusted-nix"

expect "the repository workflows satisfy the action policy" 0 "action pin check: PASS" \
  -- bash "${script_dir}/check-actions-pinned.sh" "${repo_root}/.github/workflows"

echo
echo "== check-confinement.sh =="

# G12 is a grep, which is the kind of check that silently stops matching. Each
# case adds a call site the gate is supposed to catch, in a module that is not
# on its allowlist.
clone="$(make_clone confine-tables)"
printf 'import Clean.Backend.LLZK.Basic\ndef sneaky := Config.unsafeWithTables\n' \
  > "${clone}/Clean/Backend/LLZK/Sneaky.lean"
expect "unsafeWithTables outside its modules" 1 "Config.unsafeWithTables outside" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

clone="$(make_clone confine-lower)"
printf 'import Clean.Backend.LLZK.Circuit\ndef sneaky := lowerRecognized\n' \
  > "${clone}/Clean/Backend/LLZK/Sneaky.lean"
expect "lowerRecognized outside its modules" 1 "G9-skipping entry points outside" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

clone="$(make_clone confine-compile)"
printf 'import Clean.Backend.LLZK.Circuit\ndef sneaky := compileSource\n' \
  > "${clone}/Clean/Gadgets/Sneaky.lean"
expect "compileSource outside its modules" 1 "G9-skipping entry points outside" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

# The gate must not fire on the *verified* door, or it would push authors back
# towards the unverified ones to keep the build green.
clone="$(make_clone confine-verified)"
printf 'import Clean.Backend.LLZK.WitnessCheck\ndef fine := compileSourceVerified\n' \
  > "${clone}/Clean/Gadgets/Fine.lean"
expect "compileSourceVerified is not confined" 0 "every gate-skipping entry point is confined" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

# A2. The gate reads code, so a docstring naming an entry point is not a call
# site -- which is the whole reason the allowlist could shrink. Pinned in both
# directions, because "ignores comments" is one edit away from "ignores
# everything": the second file has the name in a comment *and* in code.
clone="$(make_clone confine-prose)"
printf 'import Clean.Backend.LLZK.Circuit\n/-- Use `compile`, not `compileSource`. -/\ndef fine := 1\n' \
  > "${clone}/Clean/Gadgets/Prose.lean"
expect "a docstring mention is not a call site" 0 "every gate-skipping entry point is confined" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

clone="$(make_clone confine-prose-and-code)"
printf 'import Clean.Backend.LLZK.Circuit\n-- see `compileSource`\ndef sneaky := compileSource\n' \
  > "${clone}/Clean/Gadgets/Both.lean"
expect "a comment does not hide a call site below it" 1 "G9-skipping entry points outside" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

# The stripper must not blank code that merely follows a `--` inside a string.
clone="$(make_clone confine-string)"
printf 'import Clean.Backend.LLZK.Circuit\ndef msg := "a -- b"\ndef sneaky := compileSource\n' \
  > "${clone}/Clean/Gadgets/Str.lean"
expect "a -- inside a string does not blank the rest of the file" 1 "G9-skipping entry points outside" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

clone="$(make_clone confine-happy)"
expect "confinement happy path" 0 "every gate-skipping entry point is confined" \
  -- bash "${clone}/scripts/llzk/check-confinement.sh"

echo
echo "== worktree-lock.sh =="

# `e2e.sh` now refuses to run without the lock, so its refusal is a gate branch
# like any other and belongs here. Each case runs against a throwaway clone, so
# the lock file under test is that clone's and this machine's real one is never
# touched. LLZK_SESSION supplies the identity, which is also how a session under
# an agent harness must supply it -- see the note at the top of the script.
lock_of() { echo "$1/scripts/llzk/worktree-lock.sh"; }

clone="$(make_clone lock-unheld)"
expect "require with no lock" 1 "does not hold the worktree lock" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" require

clone="$(make_clone lock-held-by-other)"
env LLZK_SESSION=owner bash "$(lock_of "${clone}")" claim "the owner" >/dev/null
expect "require while another session holds it" 1 "held by owner" \
  -- env LLZK_SESSION=intruder bash "$(lock_of "${clone}")" require
expect "claim while another session holds it" 1 "the worktree is held by session owner" \
  -- env LLZK_SESSION=intruder bash "$(lock_of "${clone}")" claim "the intruder"
# An LLZK_SESSION owner is opaque, so "live" here is an assumption rather than an
# observation and the refusal has to say so; the provably-live case is below.
expect "reclaim while an opaque holder is recorded" 1 "liveness cannot be decided here" \
  -- env LLZK_SESSION=intruder bash "$(lock_of "${clone}")" reclaim "the intruder"
expect "require as the holder" 0 "worktree lock: held" \
  -- env LLZK_SESSION=owner bash "$(lock_of "${clone}")" require

# A numeric owner this machine *can* look up, and which is running: this shell's
# own POSIX session. The only case where "is live" is a fact.
clone="$(make_clone lock-live-numeric)"
printf '%s\na live session\n2026-01-01T00:00:00Z\n' "$(ps -o sid= -p $$ | tr -d ' ')" \
  > "${clone}/.llzk-worktree-owner"
expect "reclaim while the holder is provably live" 1 "is live; reclaim is only for" \
  -- env LLZK_SESSION=intruder bash "$(lock_of "${clone}")" reclaim "the intruder"

# The defect that motivated splitting `reclaim` out of `claim`. A lock whose
# recorded owner is a numeric session id that no longer exists used to be taken
# silently, which is precisely how a session that *did* consult the lock could
# still walk into an occupied tree: under a harness that runs each command in its
# own POSIX session, every claim is stale by the next command.
clone="$(make_clone lock-stale)"
printf '999999\na session that is gone\n2026-01-01T00:00:00Z\n' \
  > "${clone}/.llzk-worktree-owner"
expect "claim does not silently take a stale lock" 1 "reclaim '<what you are doing>'" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" claim "the next session"
expect "status reports a stale lock as reclaimable" 0 "reclaimable" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" status
expect "reclaim takes a stale lock, and says so" 0 "reclaiming a stale lock" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" reclaim "the next session"

# R6. Every case above records a *numeric* owner, which is the one kind whose
# liveness this machine can decide -- so the whole stale-lock path was gated only
# for the identity D023 introduced LLZK_SESSION to replace. For an opaque owner
# `lock_is_live` fails closed to "live", which made `reclaim` unreachable and
# `status` report an assumption as a fact. R6 walked into it on the first line of
# CURRENT.md's "Next session" and had to `rm` the file.
clone="$(make_clone lock-opaque)"
printf 'S99\na finished agent session\n2026-01-01T00:00:00Z\n' \
  > "${clone}/.llzk-worktree-owner"
expect "claim names --from for an opaque owner" 1 "reclaim '<what you are doing>' --from 'S99'" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" claim "the next session"
expect "status reports an opaque owner as undecidable" 0 "liveness undecidable" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" status
expect "bare reclaim refuses an opaque owner, and says how" 1 "--from 'S99'" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" reclaim "the next session"
expect "reclaim --from refuses the wrong owner" 1 "does not match the recorded owner" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" reclaim "the next session" --from S98
expect "reclaim --from takes an opaque lock" 0 "reclaiming a stale lock from session S99" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" reclaim "the next session" --from S99
expect "the reclaimer now holds it" 0 "worktree lock: held" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" require

# Reclaiming a tree you already hold is a relabel, not a displacement: there is
# no stale owner to announce.
expect "reclaiming your own lock does not announce a stale owner" 0 "worktree claimed by session tester" \
  -- env LLZK_SESSION=tester bash "$(lock_of "${clone}")" reclaim "a second thing"

clone="$(make_clone lock-release)"
env LLZK_SESSION=owner bash "$(lock_of "${clone}")" claim "the owner" >/dev/null
expect "only the holder may release" 1 "only the holder may release it" \
  -- env LLZK_SESSION=intruder bash "$(lock_of "${clone}")" release
expect "the holder may release" 0 "worktree released" \
  -- env LLZK_SESSION=owner bash "$(lock_of "${clone}")" release

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
printf '{"out0":"1"}\n' > "${workdir}/public.json"
printf '{"arg0":1}\n' > "${workdir}/inputs.json"
expect "llzk-witgen self-test catches a permissive shim" 1 "is not checking anything" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected.json" "${workdir}/public.json" "${workdir}"

> "${workdir}/shim/llzk-opt-mlironly" cat <<'SHIM'
#!/usr/bin/env bash
# A generic MLIR parser: rejects text that is not MLIR, accepts anything that is,
# and never runs an LLZK verifier. R5d's D-2 -- with only the non-MLIR probe, the
# self-test could not tell this from the real tool, so G3's "verifies" could be
# false while green. And this is not a strawman: LLZK 3.0.0 really does accept a
# module whose whole body is a `func.func` with no LLZK in it.
case "${1:-}" in --version) echo "LLZK version 3.0.0"; exit 0;; esac
for a in "$@"; do
  [[ -f "${a}" ]] || continue
  grep -q '^module' "${a}" && exit 0
  exit 1
done
exit 0
SHIM
chmod +x "${workdir}/shim/llzk-opt-mlironly"
expect "llzk-opt self-test catches a parser with no LLZK verifier" 1 "@compute and no" \
  -- env LLZK_OPT="${workdir}/shim/llzk-opt-mlironly" \
       bash -c 'source "$1/lib.sh"; require_llzk_opt_discriminates "$2" "$3"' \
       _ "${script_dir}" "${workdir}" "${workdir}/dummy.llzk"

> "${workdir}/shim/llzk-witgen-interp-only" cat <<'SHIM'
#!/usr/bin/env bash
# Honest on the interpreter, a no-op on the execution engine. R5d's D-1: the
# self-test ran only the default backend, so a stub execution engine made G6
# vacuous while the log differed from a real run only in tool paths.
backend=interpreter
check=""
for a in "$@"; do
  case "${a}" in
    --backend=*) backend="${a#--backend=}" ;;
    --check-output) check="next" ;;
    *) [[ "${check}" == "next" ]] && { check="${a}"; } ;;
  esac
done
[[ "${backend}" == "interpreter" ]] || exit 0
case "${check}" in *expected*|*public.json) exit 0 ;; *) exit 1 ;; esac
SHIM
chmod +x "${workdir}/shim/llzk-witgen-interp-only"
expect "llzk-witgen self-test catches a stub execution engine" 1 "execution-engine" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-interp-only" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected.json" "${workdir}/public.json" "${workdir}"

# Honest on both full-witness backends, but accepts every public expectation.
# This is the exact false green the 2026-08-22 public-output increment must make
# impossible: the older discriminator never exercised the public scope.
> "${workdir}/shim/llzk-witgen-full-only" cat <<'SHIM'
#!/usr/bin/env bash
scope=full-witness
check=""
for a in "$@"; do
  case "${a}" in
    --output-scope=*) scope="${a#--output-scope=}" ;;
    --check-output) check="next" ;;
    *) [[ "${check}" == "next" ]] && { check="${a}"; } ;;
  esac
done
[[ "${scope}" == "public" ]] && exit 0
case "${check}" in *expected*) exit 0 ;; *) exit 1 ;; esac
SHIM
chmod +x "${workdir}/shim/llzk-witgen-full-only"
expect "llzk-witgen self-test catches a permissive public scope" 1 "public-output self-test" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-full-only" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected.json" "${workdir}/public.json" "${workdir}"

echo
if (( failed > 0 )); then
  echo "FAIL: ${passed} passed, ${failed} failed"
  exit 1
fi
echo "PASS: ${passed} error paths exercised"
