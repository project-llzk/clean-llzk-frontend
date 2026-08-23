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

# Pin the complete e2e driver, not only landmarks within the headline blocks.
# Substring counts stayed green when an early `continue` made every real-tool
# call unreachable; a bounded block digest stayed green when an outside
# conditional enclosed the block. The whole-file digest and mutation controls
# near G11's tail close both false-greens.
check_e2e_wiring() {
  python3 - "$1" <<'PYEOF'
import hashlib, pathlib, sys

source = pathlib.Path(sys.argv[1]).read_text()
start = 'echo "== Xor32 exhaustive output and narrowing self-test =="'
blake = 'echo "== BLAKE3.G exhaustive interface self-test =="'
end = "# G10 is in two halves."
if source.count(start) != 1 or source.count(blake) != 1 or source.count(end) != 1:
    print("headline e2e block markers are not unique")
    raise SystemExit(1)
banner = ('echo "of that reading is what the ${vectors} vectors above test, on both LLZK"\n'
          'echo "witness backends. The @constrain half has no executor in this toolchain and so no"')
module_banner = 'echo "  ${#artifacts[@]} corpus module(s), ${vectors} input vector(s), both witgen backends,"'
if (source.count(banner) != 1 or source.count(module_banner) != 1
        or "two independent backends" in source or "circuit(s)" in source):
    print("e2e semantic-boundary banner is missing or overclaims backend independence")
    raise SystemExit(1)
actual = hashlib.sha256(source.encode()).hexdigest()
expected = "720de1d845070a344249f4c99b77a0f3d1914c5ab3219ec680aec2c5f9bc1ef6"
if actual != expected:
    print(f"headline e2e file digest mismatch: {actual}")
    raise SystemExit(1)
PYEOF
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
git -C "${clone}" checkout --quiet --force --detach \
  0e53b9f2d05f06defa2aa0a859f549b611583f10
git -C "${clone}" checkout --quiet \
  3d086f32a71d17cbddfb46c0dea63cd36c8aa552 -- Clean/Gadgets/Xor/Xor32.lean
echo "-- unexpected second overlay path" >> "${clone}/Clean/Utils/Primes.lean"
git -C "${clone}" add Clean/Gadgets/Xor/Xor32.lean Clean/Utils/Primes.lean
git -C "${clone}" -c user.email=t@t -c user.name=t commit --quiet -m "expanded overlay"
wrong_overlay="$(git -C "${clone}" rev-parse HEAD)"
mkdir -p "${clone}/scripts/llzk"
cp "${script_dir}"/*.sh "${script_dir}"/*.py "${clone}/scripts/llzk/"
sed -i "s/^clean_base=.*/clean_base=\"${wrong_overlay}\"/" \
  "${clone}/scripts/llzk/check-pins.sh"
expect "unexpected extra Clean overlay path" 1 "differs from the reviewed one-path delta" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone wrong-overlay-status)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
git -C "${clone}" checkout --quiet --force --detach \
  0e53b9f2d05f06defa2aa0a859f549b611583f10
git -C "${clone}" rm --quiet Clean/Gadgets/Xor/Xor32.lean
git -C "${clone}" -c user.email=t@t -c user.name=t commit --quiet -m "delete overlay target"
wrong_status_overlay="$(git -C "${clone}" rev-parse HEAD)"
mkdir -p "${clone}/scripts/llzk"
cp "${script_dir}"/*.sh "${script_dir}"/*.py "${clone}/scripts/llzk/"
sed -i "s/^clean_base=.*/clean_base=\"${wrong_status_overlay}\"/" \
  "${clone}/scripts/llzk/check-pins.sh"
expect "unexpected Clean overlay status" 1 "differs from the reviewed one-path delta" \
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

# S29. Xor32 is deliberately ordinary Clean core after K. These path-specific
# controls prevent a later exclusion for the adopted overlay path from hiding
# either committed or working-tree drift while the generic Primes probes above
# remain green.
clone="$(make_clone xor32-drift)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
echo "-- forbidden post-overlay Xor32 edit" >> "${clone}/Clean/Gadgets/Xor/Xor32.lean"
git -C "${clone}" -c user.email=t@t -c user.name=t commit --quiet -am "touch Xor32"
expect "a committed post-overlay Xor32 change is caught" 1 \
  "no longer byte-identical to the accepted overlay" \
  -- bash "${clone}/scripts/llzk/check-pins.sh"

clone="$(make_clone xor32-dirty)"
git -C "${clone}" remote add upstream git@github.com:Verified-zkEVM/clean.git
echo "-- forbidden uncommitted Xor32 edit" >> "${clone}/Clean/Gadgets/Xor/Xor32.lean"
expect "an uncommitted post-overlay Xor32 change is caught" 1 "uncommitted changes" \
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
expect "llzk-witgen self-test catches a permissive shim" 1 "--check-output is incomplete" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected.json" "${workdir}/public.json" "${workdir}"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1","out0":"1","out1":"2","out2":"3"}}\n' \
  > "${workdir}/strict-witness-small.json"
printf '{"out0":"1","out1":"2","out2":"3"}\n' \
  > "${workdir}/strict-public-wide.json"
expect "strict widest self-test independently requires three witness cells" 1 \
  "only 1 distinct witness cells; need 3" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" strict-sampled' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/strict-witness-small.json" "${workdir}/strict-public-wide.json" "${workdir}"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1","w1":"2","w2":"3","out0":"1"}}\n' \
  > "${workdir}/strict-full-output-small.json"
expect "strict widest self-test independently requires three full outputs" 1 \
  "only 1 distinct full-witness outputs; need 3" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" strict-sampled' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/strict-full-output-small.json" "${workdir}/strict-public-wide.json" "${workdir}"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1","w1":"2","w2":"3","out0":"1","out1":"2","out2":"3"}}\n' \
  > "${workdir}/strict-full-wide.json"
expect "strict widest self-test independently requires three public outputs" 1 \
  "only 1 distinct public outputs; need 3" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" strict-sampled' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/strict-full-wide.json" "${workdir}/public.json" "${workdir}"
expect "llzk-witgen self-test rejects an unknown discriminator mode" 1 \
  "unknown discriminator mode maybe" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" maybe' \
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

# Three content-aware partial checkers. Each is first shown green on the exact
# baseline, red on a field it really checks, and falsely green on a different
# canonical mutation it ignores. Only then is the helper required to catch it.
> "${workdir}/shim/llzk-witgen-first-public-only" cat <<'SHIM'
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
if [[ "${scope}" == "full-witness" ]]; then
  python3 - "${check}" <<'PYEOF'
import json, os, sys
with open(sys.argv[1]) as source:
    actual = json.load(source)
expected = {"w0":"1", "w1":"2", "w2":"3", "out0":"1", "out1":"2", "out2":"3"}
raise SystemExit(0 if actual.get("signals") == expected else 1)
PYEOF
  exit $?
fi
python3 - "${check}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as source:
    actual = json.load(source)
raise SystemExit(0 if actual.get("out0") == "1" else 1)
PYEOF
SHIM
chmod +x "${workdir}/shim/llzk-witgen-first-public-only"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1","w1":"2","w2":"3","out0":"1","out1":"2","out2":"3"}}\n' \
  > "${workdir}/expected-wide.json"
printf '{"out0":"1","out1":"2","out2":"3"}\n' > "${workdir}/public-wide.json"
printf '{"out0":"0","out1":"2","out2":"3"}\n' \
  > "${workdir}/manual-public-output-first.json"
printf '{"out0":"1","out1":"0","out2":"3"}\n' \
  > "${workdir}/manual-public-output-middle.json"
expect "out0-only checker accepts its correct public baseline" 0 "" \
  -- "${workdir}/shim/llzk-witgen-first-public-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=public \
       --check-output "${workdir}/public-wide.json"
expect "out0-only checker rejects the public field it checks" 1 "" \
  -- "${workdir}/shim/llzk-witgen-first-public-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=public \
       --check-output "${workdir}/manual-public-output-first.json"
expect "out0-only checker demonstrably ignores a middle public mutation" 0 "" \
  -- "${workdir}/shim/llzk-witgen-first-public-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=public \
       --check-output "${workdir}/manual-public-output-middle.json"
expect "llzk-witgen self-test catches a checker that validates only out0" 1 \
  "middle public output perturbed" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-first-public-only" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected-wide.json" "${workdir}/public-wide.json" "${workdir}"

> "${workdir}/shim/llzk-witgen-full-w0-only" cat <<'SHIM'
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
if [[ "${scope}" == "public" ]]; then
  python3 - "${check}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as source:
    actual = json.load(source)
raise SystemExit(0 if actual == {"out0":"1", "out1":"2", "out2":"3"} else 1)
PYEOF
  exit $?
fi
python3 - "${check}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as source:
    signals = json.load(source).get("signals", {})
checked = (signals.get("w0") == "1" and
           [signals.get(f"out{i}") for i in range(3)] == ["1", "2", "3"])
raise SystemExit(0 if checked else 1)
PYEOF
SHIM
chmod +x "${workdir}/shim/llzk-witgen-full-w0-only"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"0","w1":"2","w2":"3","out0":"1","out1":"2","out2":"3"}}\n' \
  > "${workdir}/manual-witness-first.json"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1","w1":"0","w2":"3","out0":"1","out1":"2","out2":"3"}}\n' \
  > "${workdir}/manual-witness-middle.json"
expect "w0-only checker accepts its correct full-witness baseline" 0 "" \
  -- "${workdir}/shim/llzk-witgen-full-w0-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=full-witness \
       --check-output "${workdir}/expected-wide.json"
expect "w0-only checker rejects the witness cell it checks" 1 "" \
  -- "${workdir}/shim/llzk-witgen-full-w0-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=full-witness \
       --check-output "${workdir}/manual-witness-first.json"
expect "w0-only checker demonstrably ignores a middle witness-cell mutation" 0 "" \
  -- "${workdir}/shim/llzk-witgen-full-w0-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=full-witness \
       --check-output "${workdir}/manual-witness-middle.json"
expect "llzk-witgen self-test catches a checker that validates only w0" 1 \
  "witness group's middle field perturbed" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-full-w0-only" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected-wide.json" "${workdir}/public-wide.json" "${workdir}"

> "${workdir}/shim/llzk-witgen-full-out0-only" cat <<'SHIM'
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
if [[ "${scope}" == "public" ]]; then
  python3 - "${check}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as source:
    actual = json.load(source)
raise SystemExit(0 if actual == {"out0":"1", "out1":"2", "out2":"3"} else 1)
PYEOF
  exit $?
fi
python3 - "${check}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as source:
    signals = json.load(source).get("signals", {})
checked = ([signals.get(f"w{i}") for i in range(3)] == ["1", "2", "3"] and
           signals.get("out0") == "1")
raise SystemExit(0 if checked else 1)
PYEOF
SHIM
chmod +x "${workdir}/shim/llzk-witgen-full-out0-only"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1","w1":"2","w2":"3","out0":"0","out1":"2","out2":"3"}}\n' \
  > "${workdir}/manual-full-output-first.json"
printf '{"inputs":{"arg0":"1"},"signals":{"w0":"1","w1":"2","w2":"3","out0":"1","out1":"0","out2":"3"}}\n' \
  > "${workdir}/manual-full-output-middle.json"
expect "full out0-only checker accepts its correct full-witness baseline" 0 "" \
  -- "${workdir}/shim/llzk-witgen-full-out0-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=full-witness \
       --check-output "${workdir}/expected-wide.json"
expect "full out0-only checker rejects the output field it checks" 1 "" \
  -- "${workdir}/shim/llzk-witgen-full-out0-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=full-witness \
       --check-output "${workdir}/manual-full-output-first.json"
expect "full out0-only checker demonstrably ignores a middle output mutation" 0 "" \
  -- "${workdir}/shim/llzk-witgen-full-out0-only" "${workdir}/dummy.llzk" \
       --inputs "${workdir}/inputs.json" --output-scope=full-witness \
       --check-output "${workdir}/manual-full-output-middle.json"
expect "full-witness self-test catches a checker that validates only out0" 1 \
  "output group's middle field perturbed" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-full-out0-only" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected-wide.json" "${workdir}/public-wide.json" "${workdir}"

# JSON object order is not a signal-number order: lexically, out10 precedes
# out2 and out9 is last. This checker rejects only semantic indices 0, 6, and
# 11, so the helper goes green only if it sorts the numeric suffixes itself.
> "${workdir}/shim/llzk-witgen-numeric-positions" cat <<'SHIM'
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
python3 - "${scope}" "${check}" <<'PYEOF'
import json, os, sys

scope, path = sys.argv[1:]
with open(path) as source:
    actual = json.load(source)
if scope == "full-witness":
    values = actual.get("signals", {})
    baseline = {f"w{i}": "1" for i in range(12)}
    baseline.update({f"out{i}": "1" for i in range(12)})
else:
    values = actual
    baseline = {f"out{i}": "1" for i in range(12)}
if values == baseline:
    raise SystemExit(0)

differences = [key for key in baseline
               if values.get(key) != baseline[key]]
name = os.path.basename(path)
position = next((label for label in ("first", "middle", "last")
                 if name.endswith(f"-{label}.json")), None)
index = {"first": 0, "middle": 6, "last": 11}.get(position)
group = "w" if scope == "full-witness" and "-witness-" in name else "out"
expected = None if index is None else f"{group}{index}"
# Reject exactly the intended canonical 1 -> 0 mutation. An incorrect lexical
# target is accepted, which makes the surrounding discriminator fail closed.
correct = (differences == [expected] and values.get(expected) == "0"
           and set(values) == set(baseline))
raise SystemExit(1 if correct else 0)
PYEOF
SHIM
chmod +x "${workdir}/shim/llzk-witgen-numeric-positions"
printf '{"inputs":{"arg0":"1"},"signals":{"w10":"1","w2":"1","w0":"1","w11":"1","w5":"1","w1":"1","w9":"1","w3":"1","w8":"1","w4":"1","w7":"1","w6":"1","out10":"1","out2":"1","out0":"1","out11":"1","out5":"1","out1":"1","out9":"1","out3":"1","out8":"1","out4":"1","out7":"1","out6":"1"}}\n' \
  > "${workdir}/expected-scrambled-12.json"
printf '{"out10":"1","out2":"1","out0":"1","out11":"1","out5":"1","out1":"1","out9":"1","out3":"1","out8":"1","out4":"1","out7":"1","out6":"1"}\n' \
  > "${workdir}/public-scrambled-12.json"
expect "witness discriminator uses numeric first middle and last positions" 0 \
  "red on distinct first/middle/last" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-numeric-positions" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" strict-sampled' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/inputs.json" \
       "${workdir}/expected-scrambled-12.json" "${workdir}/public-scrambled-12.json" "${workdir}"

# Xor32 has four outputs, so a first/middle/last probe samples out0/out2/out3
# and misses out1. These fixtures exercise the exhaustive-output and old-raw
# alternate branches before the real promotion relies on them.
printf '{"arg0":"2013265920","arg1":"65536","arg2":"1000","arg3":"65706","arg4":"257","arg5":"511","arg6":"65535","arg7":"2013265920"}\n' \
  > "${workdir}/xor-inputs.json"
printf '{"inputs":{"arg0":"2013265920","arg1":"65536","arg2":"1000","arg3":"65706","arg4":"257","arg5":"511","arg6":"65535","arg7":"2013265920"},"signals":{"w0":"1","w1":"255","w2":"23","w3":"170","out0":"1","out1":"255","out2":"23","out3":"170"}}\n' \
  > "${workdir}/xor-expected.json"
printf '{"out0":"1","out1":"255","out2":"23","out3":"170"}\n' \
  > "${workdir}/xor-public.json"

expect "Xor32 raw generator produces the exact old full and public results" 0 "" \
  -- bash -c '
       source "$1/lib.sh"
       llzk_xor32_raw_expectations "$2" "$3" "$4" "$5" "$6"
       python3 -c '\''import json,sys
full=json.load(open(sys.argv[1])); public=json.load(open(sys.argv[2]))
raw=["256","66047","64535","65705"]
want={f"w{i}":v for i,v in enumerate(raw)}
want.update({f"out{i}":v for i,v in enumerate(raw)})
raise SystemExit(0 if full["signals"]==want and public=={f"out{i}":v for i,v in enumerate(raw)} else 1)'\'' "$5" "$6"
     ' _ "${script_dir}" "${workdir}/xor-inputs.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public.json" "${workdir}/xor-raw-expected.json" \
       "${workdir}/xor-raw-public.json"

printf '{"arg0":"2013265920","arg1":"65536","arg2":"1000","arg3":"65706","arg4":"257","arg5":"511","arg6":"65535"}\n' \
  > "${workdir}/xor-short-inputs.json"
expect "Xor32 raw generator rejects a wrong input layout" 1 "exactly canonical arg0 through arg7" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-short-inputs.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"

printf '{"out0":"1","out1":"255","out2":"24","out3":"170"}\n' \
  > "${workdir}/xor-public-not-narrowed.json"
expect "Xor32 raw generator rejects a baseline that is not narrowed" 1 \
  "checked expectation is not narrowed at lane 2" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public-not-narrowed.json" \
       "${workdir}/unused-full.json" "${workdir}/unused-public.json"

printf '{"arg0":"0","arg1":"0","arg2":"0","arg3":"0","arg4":"0","arg5":"0","arg6":"0","arg7":"0"}\n' \
  > "${workdir}/xor-collision-inputs.json"
printf '{"inputs":{"arg0":"0","arg1":"0","arg2":"0","arg3":"0","arg4":"0","arg5":"0","arg6":"0","arg7":"0"},"signals":{"w0":"0","w1":"0","w2":"0","w3":"0","out0":"0","out1":"0","out2":"0","out3":"0"}}\n' \
  > "${workdir}/xor-collision-expected.json"
printf '{"out0":"0","out1":"0","out2":"0","out3":"0"}\n' \
  > "${workdir}/xor-collision-public.json"
expect "Xor32 raw generator rejects a raw/narrowed collision" 1 \
  "raw XOR does not differ at lane 0" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-collision-inputs.json" "${workdir}/xor-collision-expected.json" \
       "${workdir}/xor-collision-public.json" \
       "${workdir}/unused-full.json" "${workdir}/unused-public.json"

python3 - "${workdir}" <<'PYEOF'
import copy, json, os, sys

directory = sys.argv[1]
def load(name):
    with open(os.path.join(directory, name)) as source:
        return json.load(source)
def write(name, value):
    with open(os.path.join(directory, name), "w") as output:
        json.dump(value, output)

inputs = load("xor-inputs.json")
full = load("xor-expected.json")
public = load("xor-public.json")
raw_full = load("xor-raw-expected.json")
raw_public = load("xor-raw-public.json")

changed = copy.deepcopy(full); del changed["signals"]["out3"]
write("xor-full-short.json", changed)
changed = copy.deepcopy(public); del changed["out3"]
write("xor-public-short.json", changed)
changed = copy.deepcopy(full); changed["signals"]["out2"] = "24"
write("xor-full-public-disagree.json", changed)
changed = copy.deepcopy(raw_full); changed["inputs"]["arg0"] = "0"
write("xor-raw-full-wrong-input.json", changed)
changed = copy.deepcopy(raw_full); del changed["signals"]["w3"]
write("xor-raw-full-short-signals.json", changed)
changed = copy.deepcopy(raw_full); changed["signals"]["out2"] = "64536"
write("xor-raw-full-disagree.json", changed)
changed = copy.deepcopy(inputs); changed["arg0"] = "not-decimal"
write("xor-inputs-nondecimal.json", changed)
changed = copy.deepcopy(inputs); changed["arg0"] = True
write("xor-inputs-boolean.json", changed)
changed = copy.deepcopy(inputs); changed["arg0"] = 1.5
write("xor-inputs-float.json", changed)
changed = copy.deepcopy(inputs); changed["arg0"] = "2013265921"
write("xor-inputs-noncanonical.json", changed)
changed = copy.deepcopy(full); del changed["signals"]["w3"]
write("xor-expected-short-signals.json", changed)
changed = copy.deepcopy(full); changed["inputs"]["arg0"] = "0"
write("xor-expected-wrong-inputs.json", changed)
changed = copy.deepcopy(full); changed["signals"]["w2"] = "24"
write("xor-expected-wrong-witness.json", changed)
changed = copy.deepcopy(full); changed["signals"]["out2"] = "24"
write("xor-expected-wrong-output.json", changed)
PYEOF

expect "Xor32 raw generator rejects a nondecimal input" 1 \
  "inputs must be integers or canonical decimal strings" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs-nondecimal.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects a boolean input" 1 \
  "inputs must be integers or canonical decimal strings" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs-boolean.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects a lossy float input" 1 \
  "inputs must be integers or canonical decimal strings" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs-float.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects a noncanonical input" 1 \
  "input is not a canonical Babybear representative" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs-noncanonical.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects a wrong full layout" 1 \
  "full expectation has the wrong inputs or signal layout" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs.json" "${workdir}/xor-expected-short-signals.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects full-witness input drift" 1 \
  "full expectation has the wrong inputs or signal layout" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs.json" "${workdir}/xor-expected-wrong-inputs.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects a non-narrowed witness cell" 1 \
  "checked expectation is not narrowed at lane 2" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs.json" "${workdir}/xor-expected-wrong-witness.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects a non-narrowed full output" 1 \
  "checked expectation is not narrowed at lane 2" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs.json" "${workdir}/xor-expected-wrong-output.json" \
       "${workdir}/xor-public.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"
expect "Xor32 raw generator rejects a wrong public layout" 1 \
  "public expectation must be exactly out0 through out3" \
  -- run_helper llzk_xor32_raw_expectations \
       "${workdir}/xor-inputs.json" "${workdir}/xor-expected.json" \
       "${workdir}/xor-public-short.json" "${workdir}/unused-full.json" "${workdir}/unused-public.json"

expect "exhaustive discriminator requires an output count" 1 \
  "exhaustive-output count must be a positive integer" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}"
expect "exhaustive discriminator rejects a zero output count" 1 \
  "exhaustive-output count must be a positive integer" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 0' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}"
expect "sampled discriminator rejects exhaustive-only arguments" 1 \
  "sampled mode takes no output count or alternate" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" sampled 4' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}"
expect "exhaustive discriminator rejects a one-sided alternate" 1 \
  "alternate full and public expectations must be supplied together" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-expected.json"
expect "exhaustive discriminator rejects a public-only alternate" 1 \
  "alternate full and public expectations must be supplied together" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "" "$7"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-public.json"
expect "exhaustive discriminator rejects a wrong full-output layout" 1 \
  "full witness outputs are" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-full-short.json" "${workdir}/xor-public.json" "${workdir}"
expect "exhaustive discriminator rejects a wrong public-output layout" 1 \
  "public outputs are" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public-short.json" "${workdir}"
expect "exhaustive discriminator rejects full/public baseline disagreement" 1 \
  "full and public output expectations disagree" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-full-public-disagree.json" "${workdir}/xor-public.json" "${workdir}"

printf '{"out0":"256","out1":"66047","out2":"64535"}\n' \
  > "${workdir}/xor-raw-public-wrong-keys.json"
expect "exhaustive discriminator rejects alternate key-set drift" 1 \
  "alternate public expectation has a different output key set" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-expected.json" "${workdir}/xor-raw-public-wrong-keys.json"

printf '{"inputs":{"arg0":"2013265920","arg1":"65536","arg2":"1000","arg3":"65706","arg4":"257","arg5":"511","arg6":"65535","arg7":"2013265920"},"signals":{"w0":"256","w1":"255","w2":"64535","w3":"65705","out0":"256","out1":"255","out2":"64535","out3":"65705"}}\n' \
  > "${workdir}/xor-raw-full-noop.json"
printf '{"out0":"256","out1":"255","out2":"64535","out3":"65705"}\n' \
  > "${workdir}/xor-raw-public-noop.json"
expect "exhaustive discriminator rejects an alternate with a no-op output" 1 \
  "alternate output out1 does not differ from the baseline" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-full-noop.json" "${workdir}/xor-raw-public-noop.json"
expect "exhaustive discriminator rejects alternate input drift" 1 \
  "alternate full expectation belongs to different inputs" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-full-wrong-input.json" "${workdir}/xor-raw-public.json"
expect "exhaustive discriminator rejects alternate signal-key drift" 1 \
  "alternate full expectation has a different signal key set" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-full-short-signals.json" "${workdir}/xor-raw-public.json"
expect "exhaustive discriminator rejects alternate full/public disagreement" 1 \
  "alternate full/public output out2 disagrees" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-full-disagree.json" "${workdir}/xor-raw-public.json"

printf '{"inputs":{"arg0":"2013265920","arg1":"65536","arg2":"1000","arg3":"65706","arg4":"257","arg5":"511","arg6":"65535","arg7":"2013265920"},"signals":{"w0":"1","w1":"255","w2":"23","w3":"170","out0":"0","out1":"255","out2":"23","out3":"170"}}\n' \
  > "${workdir}/xor-full-out0-mutated.json"
printf '{"inputs":{"arg0":"2013265920","arg1":"65536","arg2":"1000","arg3":"65706","arg4":"257","arg5":"511","arg6":"65535","arg7":"2013265920"},"signals":{"w0":"1","w1":"255","w2":"23","w3":"170","out0":"1","out1":"0","out2":"23","out3":"170"}}\n' \
  > "${workdir}/xor-full-out1-mutated.json"
printf '{"out0":"0","out1":"255","out2":"23","out3":"170"}\n' \
  > "${workdir}/xor-public-out0-mutated.json"
printf '{"out0":"1","out1":"0","out2":"23","out3":"170"}\n' \
  > "${workdir}/xor-public-out1-mutated.json"

> "${workdir}/shim/llzk-witgen-xor-controlled" cat <<'SHIM'
#!/usr/bin/env bash
scope=full-witness
check=""
for a in "$@"; do
  case "${a}" in
    --output-scope=*) scope="${a#--output-scope=}" ;;
    --check-output) check="next" ;;
    *) [[ "${check}" == "next" ]] && check="${a}" ;;
  esac
done
python3 - "${XOR_SHIM_MODE:?}" "${scope}" "${check}" <<'PYEOF'
import json, os, sys
mode, scope, path = sys.argv[1:]
actual = json.load(open(path))
inputs = {f"arg{i}": str(v) for i, v in enumerate(
    [2013265920, 65536, 1000, 65706, 257, 511, 65535, 2013265920])}
narrow = ["1", "255", "23", "170"]
raw = ["256", "66047", "64535", "65705"]
signals = {f"w{i}": v for i, v in enumerate(narrow)}
signals.update({f"out{i}": v for i, v in enumerate(narrow)})
raw_signals = {f"w{i}": v for i, v in enumerate(raw)}
raw_signals.update({f"out{i}": v for i, v in enumerate(raw)})
baseline_full = {"inputs": inputs, "signals": signals}
raw_full = {"inputs": inputs, "signals": raw_signals}
baseline_public = {f"out{i}": v for i, v in enumerate(narrow)}
raw_public = {f"out{i}": v for i, v in enumerate(raw)}

if scope == "full-witness":
    if mode == "full-ignore-out1":
        got = actual.get("signals", {})
        ok = (actual.get("inputs") == inputs and set(got) == set(signals)
              and all(got[key] == value for key, value in signals.items() if key != "out1"))
    elif mode == "full-accept-raw":
        ok = actual == baseline_full or actual == raw_full
    elif mode == "full-path-raw-only":
        ok = (actual == baseline_full or
              (actual == raw_full and "raw" not in os.path.basename(path)))
    else:
        ok = actual == baseline_full
else:
    if mode == "public-ignore-out1":
        ok = (set(actual) == set(baseline_public)
              and all(actual[key] == value for key, value in baseline_public.items()
                      if key != "out1"))
    elif mode == "public-accept-raw":
        ok = actual == baseline_public or actual == raw_public
    elif mode == "public-path-raw-only":
        ok = (actual == baseline_public or
              (actual == raw_public and "raw" not in os.path.basename(path)))
    else:
        ok = actual == baseline_public
raise SystemExit(0 if ok else 1)
PYEOF
SHIM
chmod +x "${workdir}/shim/llzk-witgen-xor-controlled"

expect "exhaustive Xor discriminator accepts an honest content-aware checker" 0 \
  "every one of 4 full/public outputs plus alternate expectations" \
  -- env XOR_SHIM_MODE=exact LLZK_WITGEN="${workdir}/shim/llzk-witgen-xor-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-expected.json" "${workdir}/xor-raw-public.json"

expect "full out1-omitting checker accepts its baseline" 0 "" \
  -- env XOR_SHIM_MODE=full-ignore-out1 "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-expected.json"
expect "full out1-omitting checker rejects out0" 1 "" \
  -- env XOR_SHIM_MODE=full-ignore-out1 "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-full-out0-mutated.json"
expect "full out1-omitting checker demonstrably ignores out1" 0 "" \
  -- env XOR_SHIM_MODE=full-ignore-out1 "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-full-out1-mutated.json"
expect "exhaustive discriminator catches a full checker that omits out1" 1 \
  "output group's index-1 field perturbed" \
  -- env XOR_SHIM_MODE=full-ignore-out1 LLZK_WITGEN="${workdir}/shim/llzk-witgen-xor-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}"

expect "public out1-omitting checker accepts its baseline" 0 "" \
  -- env XOR_SHIM_MODE=public-ignore-out1 "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-public.json"
expect "public out1-omitting checker rejects out0" 1 "" \
  -- env XOR_SHIM_MODE=public-ignore-out1 "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-public-out0-mutated.json"
expect "public out1-omitting checker demonstrably ignores out1" 0 "" \
  -- env XOR_SHIM_MODE=public-ignore-out1 "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-public-out1-mutated.json"
expect "exhaustive discriminator catches a public checker that omits out1" 1 \
  "index-1 public output perturbed" \
  -- env XOR_SHIM_MODE=public-ignore-out1 LLZK_WITGEN="${workdir}/shim/llzk-witgen-xor-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}"

expect "raw-full-accepting checker accepts its baseline" 0 "" \
  -- env XOR_SHIM_MODE=full-accept-raw "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-expected.json"
expect "raw-full-accepting checker rejects an individual output mutation" 1 "" \
  -- env XOR_SHIM_MODE=full-accept-raw "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-full-out0-mutated.json"
expect "raw-full-accepting checker demonstrably accepts the raw witness" 0 "" \
  -- env XOR_SHIM_MODE=full-accept-raw "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-raw-expected.json"
expect "exhaustive discriminator catches a checker that accepts the raw full witness" 1 \
  "accepted the alternate full witness" \
  -- env XOR_SHIM_MODE=full-accept-raw LLZK_WITGEN="${workdir}/shim/llzk-witgen-xor-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-expected.json" "${workdir}/xor-raw-public.json"

expect "raw-public-accepting checker accepts its baseline" 0 "" \
  -- env XOR_SHIM_MODE=public-accept-raw "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-public.json"
expect "raw-public-accepting checker rejects an individual output mutation" 1 "" \
  -- env XOR_SHIM_MODE=public-accept-raw "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-public-out0-mutated.json"
expect "raw-public-accepting checker demonstrably accepts the raw output" 0 "" \
  -- env XOR_SHIM_MODE=public-accept-raw "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-raw-public.json"
expect "exhaustive discriminator catches a checker that accepts the raw public output" 1 \
  "accepted the alternate public output" \
  -- env XOR_SHIM_MODE=public-accept-raw LLZK_WITGEN="${workdir}/shim/llzk-witgen-xor-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-expected.json" "${workdir}/xor-raw-public.json"

# A path-aware shim can appear honest if the helper passes a predictably named
# `raw` file directly. The helper must copy alternates to PID-derived names
# before presenting them to witgen, exactly as it does for scalar mutations.
expect "full path-specializing checker accepts its baseline" 0 "" \
  -- env XOR_SHIM_MODE=full-path-raw-only "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-expected.json"
expect "full path-specializing checker rejects an individual mutation" 1 "" \
  -- env XOR_SHIM_MODE=full-path-raw-only "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-full-out0-mutated.json"
expect "full path-specializing checker rejects only the predictable raw path" 1 "" \
  -- env XOR_SHIM_MODE=full-path-raw-only "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/xor-raw-expected.json"
expect "PID-derived non-raw path catches the full path-specializing checker" 1 \
  "accepted the alternate full witness" \
  -- env XOR_SHIM_MODE=full-path-raw-only LLZK_WITGEN="${workdir}/shim/llzk-witgen-xor-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-expected.json" "${workdir}/xor-raw-public.json"

expect "public path-specializing checker accepts its baseline" 0 "" \
  -- env XOR_SHIM_MODE=public-path-raw-only "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-public.json"
expect "public path-specializing checker rejects an individual mutation" 1 "" \
  -- env XOR_SHIM_MODE=public-path-raw-only "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-public-out0-mutated.json"
expect "public path-specializing checker rejects only the predictable raw path" 1 "" \
  -- env XOR_SHIM_MODE=public-path-raw-only "${workdir}/shim/llzk-witgen-xor-controlled" \
       "${workdir}/dummy.llzk" --output-scope=public \
       --check-output "${workdir}/xor-raw-public.json"
expect "PID-derived non-raw path catches the public path-specializing checker" 1 \
  "accepted the alternate public output" \
  -- env XOR_SHIM_MODE=public-path-raw-only LLZK_WITGEN="${workdir}/shim/llzk-witgen-xor-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-outputs 4 "$7" "$8"' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/xor-inputs.json" \
       "${workdir}/xor-expected.json" "${workdir}/xor-public.json" "${workdir}" \
       "${workdir}/xor-raw-expected.json" "${workdir}/xor-raw-public.json"

# BLAKE3.G's promoted interface is 72 inputs, 96 witness cells, and 64 public
# outputs. Build a synthetic carrier of exactly that shape, then use a
# content-aware shim which rejects only genuine one-key 1 -> 0 mutations. Its
# log proves the exhaustive helper reaches every distinct key on both backends.
python3 - "${workdir}" <<'PYEOF'
import copy, json, pathlib, sys

directory = pathlib.Path(sys.argv[1])
inputs = {f"arg{i}": str(i % 256) for i in range(72)}
signals = {f"w{i}": "1" for i in range(96)}
signals.update({f"out{i}": "1" for i in range(64)})
full = {"inputs": inputs, "signals": signals}
public = {f"out{i}": "1" for i in range(64)}

def write(name, value):
    (directory / name).write_text(json.dumps(value))

write("blake-inputs.json", inputs)
write("blake-expected.json", full)
write("blake-public.json", public)
changed = copy.deepcopy(full); changed["signals"]["w42"] = "0"
write("blake-full-w42-mutated.json", changed)
changed = copy.deepcopy(full); del changed["signals"]["w95"]
write("blake-full-missing-w95.json", changed)
changed = copy.deepcopy(full); changed["signals"]["w96"] = "1"
write("blake-full-extra-w96.json", changed)
changed = copy.deepcopy(full); changed["signals"]["w01"] = "1"
write("blake-full-malformed-w01.json", changed)
changed = copy.deepcopy(full); del changed["signals"]["out63"]
write("blake-full-missing-out63.json", changed)
changed = copy.deepcopy(public); changed["out64"] = "1"
write("blake-public-extra-out64.json", changed)
changed = copy.deepcopy(inputs); del changed["arg71"]
write("blake-inputs-missing-arg71.json", changed)
changed = copy.deepcopy(inputs); changed["arg72"] = "1"
write("blake-inputs-extra-arg72.json", changed)
changed = copy.deepcopy(full); changed["inputs"]["arg0"] = "2"
write("blake-full-input-drift.json", changed)
changed = copy.deepcopy(full); changed["signals"]["out17"] = "2"
write("blake-full-public-disagree.json", changed)
changed = copy.deepcopy(full); changed["signals"]["w42"] = True
write("blake-full-boolean.json", changed)
changed = copy.deepcopy(public); changed["out17"] = 1.5
write("blake-public-float.json", changed)
changed = copy.deepcopy(inputs); changed["arg0"] = "2013265921"
write("blake-inputs-noncanonical.json", changed)
changed_full = copy.deepcopy(full); changed_full["inputs"] = changed
write("blake-full-noncanonical-input.json", changed_full)
PYEOF

> "${workdir}/shim/llzk-witgen-blake-controlled" cat <<'SHIM'
#!/usr/bin/env bash
scope=full-witness
backend=interpreter
check=""
for a in "$@"; do
  case "${a}" in
    --output-scope=*) scope="${a#--output-scope=}" ;;
    --backend=*) backend="${a#--backend=}" ;;
    --check-output) check="next" ;;
    *) [[ "${check}" == "next" ]] && check="${a}" ;;
  esac
done
python3 - "${BLAKE_SHIM_MODE:-exact}" "${BLAKE_SHIM_LOG:-}" \
  "${backend}" "${scope}" "${check}" <<'PYEOF'
import json, sys

mode, log_path, backend, scope, path = sys.argv[1:]
with open(path) as source:
    actual = json.load(source)
inputs = {f"arg{i}": str(i % 256) for i in range(72)}
if scope == "full-witness":
    baseline = {f"w{i}": "1" for i in range(96)}
    baseline.update({f"out{i}": "1" for i in range(64)})
    if actual.get("inputs") != inputs or not isinstance(actual.get("signals"), dict):
        raise SystemExit(0)
    values = actual["signals"]
else:
    baseline = {f"out{i}": "1" for i in range(64)}
    values = actual
if not isinstance(values, dict) or set(values) != set(baseline):
    raise SystemExit(0)
differences = [key for key in baseline if values[key] != baseline[key]]
if not differences:
    label = "baseline"
    status = 0
elif len(differences) == 1 and values[differences[0]] == "0":
    label = differences[0]
    status = 0 if mode == "ignore-w42" and scope == "full-witness" and label == "w42" else 1
else:
    label = "malformed"
    status = 0
if log_path:
    with open(log_path, "a") as log:
        log.write(f"{backend} {scope} {label}\n")
raise SystemExit(status)
PYEOF
SHIM
chmod +x "${workdir}/shim/llzk-witgen-blake-controlled"

expect "BLAKE exhaustive interface reaches every exact key" 0 \
  "red on every witness cell and every full/public output" \
  -- env BLAKE_SHIM_MODE=exact BLAKE_SHIM_LOG="${workdir}/blake-shim.log" \
       LLZK_WITGEN="${workdir}/shim/llzk-witgen-blake-controlled" \
       bash -c ': > "$7"; source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 96 64' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}" \
       "${workdir}/blake-shim.log"

expect "BLAKE exhaustive interface mutation log is complete" 0 "" \
  -- python3 - "${workdir}/blake-shim.log" <<'PYEOF'
import collections, sys

with open(sys.argv[1]) as source:
    actual = collections.Counter(line.strip() for line in source if line.strip())
expected = collections.Counter()
for backend in ("interpreter", "execution-engine"):
    expected[f"{backend} full-witness baseline"] += 1
    expected[f"{backend} public baseline"] += 1
    for i in range(96):
        expected[f"{backend} full-witness w{i}"] += 1
    for i in range(64):
        expected[f"{backend} full-witness out{i}"] += 1
        expected[f"{backend} public out{i}"] += 1
raise SystemExit(0 if actual == expected else 1)
PYEOF

expect "BLAKE partial checker accepts its baseline" 0 "" \
  -- env BLAKE_SHIM_MODE=ignore-w42 "${workdir}/shim/llzk-witgen-blake-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/blake-expected.json"
expect "BLAKE partial checker demonstrably ignores w42" 0 "" \
  -- env BLAKE_SHIM_MODE=ignore-w42 "${workdir}/shim/llzk-witgen-blake-controlled" \
       "${workdir}/dummy.llzk" --output-scope=full-witness \
       --check-output "${workdir}/blake-full-w42-mutated.json"
expect "BLAKE exhaustive interface catches a checker that ignores w42" 1 \
  "witness group's index-42 field perturbed" \
  -- env BLAKE_SHIM_MODE=ignore-w42 \
       LLZK_WITGEN="${workdir}/shim/llzk-witgen-blake-controlled" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 96 64' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"

expect "BLAKE exhaustive interface requires an input count" 1 \
  "input count must be a positive integer" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"
expect "BLAKE exhaustive interface rejects a zero witness count" 1 \
  "witness count must be a positive integer" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 0 64' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"
expect "BLAKE exhaustive interface rejects a nonnumeric output count" 1 \
  "output count must be a positive integer" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 96 sixty-four' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"
expect "BLAKE exhaustive interface rejects an empty tenth and nonempty eleventh argument" 1 \
  "mode takes exactly three counts" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 96 64 "" bypass' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"
expect "BLAKE exhaustive interface uses a valid positive input count" 1 \
  "inputs are not exactly arg0 through arg70" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 71 96 64' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"
expect "BLAKE exhaustive interface uses a valid positive witness count" 1 \
  "full witness has the wrong exact w{k}/out{j} signal layout" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 95 64' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"
expect "BLAKE exhaustive interface uses a valid positive output count" 1 \
  "full witness has the wrong exact w{k}/out{j} signal layout" \
  -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
       bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 96 63' \
       _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
       "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}"

while IFS='|' read -r blake_count_label blake_count_message blake_count_words; do
  read -r -a blake_count_args <<<"${blake_count_words}"
  expect "BLAKE exhaustive interface rejects ${blake_count_label}" 1 \
    "${blake_count_message}" \
    -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
         bash -c 'source "$1/lib.sh"; shift; require_llzk_witgen_discriminates "$@"' \
         _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/blake-inputs.json" \
         "${workdir}/blake-expected.json" "${workdir}/blake-public.json" "${workdir}" \
         exhaustive-interface "${blake_count_args[@]}"
done <<'COUNT_CASES'
a zero input count|input count must be a positive integer|0 96 64
a nonnumeric input count|input count must be a positive integer|seventy-two 96 64
a missing witness count|witness count must be a positive integer|72
a nonnumeric witness count|witness count must be a positive integer|72 ninety-six 64
a missing output count|output count must be a positive integer|72 96
a zero output count|output count must be a positive integer|72 96 0
an extra argument|mode takes exactly three counts|72 96 64 extra
COUNT_CASES

while IFS='|' read -r blake_label blake_full blake_inputs blake_public blake_error; do
  expect "BLAKE exhaustive interface rejects ${blake_label}" 1 \
    "${blake_error}" \
    -- env LLZK_WITGEN="${workdir}/shim/llzk-witgen-permissive" \
         bash -c 'source "$1/lib.sh"; require_llzk_witgen_discriminates "$2" "$3" "$4" "$5" "$6" exhaustive-interface 72 96 64' \
         _ "${script_dir}" "${workdir}/dummy.llzk" "${workdir}/${blake_inputs}" \
         "${workdir}/${blake_full}" "${workdir}/${blake_public}" "${workdir}"
done <<'BLAKE_BAD_CASES'
missing-w95|blake-full-missing-w95.json|blake-inputs.json|blake-public.json|full witness has the wrong exact w{k}/out{j} signal layout
extra-w96|blake-full-extra-w96.json|blake-inputs.json|blake-public.json|full witness has the wrong exact w{k}/out{j} signal layout
malformed-w01|blake-full-malformed-w01.json|blake-inputs.json|blake-public.json|full witness has the wrong exact w{k}/out{j} signal layout
missing-out63|blake-full-missing-out63.json|blake-inputs.json|blake-public.json|full witness has the wrong exact w{k}/out{j} signal layout
extra-public-out64|blake-expected.json|blake-inputs.json|blake-public-extra-out64.json|public outputs are
missing-arg71|blake-expected.json|blake-inputs-missing-arg71.json|blake-public.json|inputs are not exactly arg0 through arg71
extra-arg72|blake-expected.json|blake-inputs-extra-arg72.json|blake-public.json|inputs are not exactly arg0 through arg71
full-input-drift|blake-full-input-drift.json|blake-inputs.json|blake-public.json|full-witness inputs disagree with the supplied input document
full-public-disagree|blake-full-public-disagree.json|blake-inputs.json|blake-public.json|full and public output expectations disagree
boolean-signal|blake-full-boolean.json|blake-inputs.json|blake-public.json|full witness contains a noncanonical Babybear scalar
float-public|blake-expected.json|blake-inputs.json|blake-public-float.json|public output contains a noncanonical Babybear scalar
noncanonical-input|blake-full-noncanonical-input.json|blake-inputs-noncanonical.json|blake-public.json|input document contains a noncanonical Babybear scalar
BLAKE_BAD_CASES

mkdir -p "${workdir}/public-widths"
printf '{"out0":"1"}\n' > "${workdir}/public-widths/AThin.0.public.json"
printf '{"out0":"1","out1":"2","out2":"3"}\n' \
  > "${workdir}/public-widths/MiddleWide.0.public.json"
printf '{"out0":"1","out1":"2"}\n' > "${workdir}/public-widths/ZThin.0.public.json"
touch "${workdir}/public-widths/AThin.0.inputs.json" \
  "${workdir}/public-widths/MiddleWide.0.inputs.json" \
  "${workdir}/public-widths/ZThin.0.inputs.json"
expect "widest public-output artifact is selected from emitted expectations" 0 \
  "MiddleWide.0.inputs.json" \
  -- run_helper llzk_widest_public_input "${workdir}/public-widths"

mkdir -p "${workdir}/public-width-tie"
printf '{"out0":"1","out1":"2","out2":"3"}\n' \
  > "${workdir}/public-width-tie/AEqual.0.public.json"
printf '{"out0":"1","out1":"2","out2":"3"}\n' \
  > "${workdir}/public-width-tie/ZEqual.0.public.json"
touch "${workdir}/public-width-tie/AEqual.0.inputs.json" \
  "${workdir}/public-width-tie/ZEqual.0.inputs.json"
expect "widest selector resolves equal widths deterministically" 0 \
  "ZEqual.0.inputs.json" \
  -- run_helper llzk_widest_public_input "${workdir}/public-width-tie"

mkdir -p "${workdir}/public-width-malformed"
printf '[]\n' > "${workdir}/public-width-malformed/Broken.0.public.json"
touch "${workdir}/public-width-malformed/Broken.0.inputs.json"
expect "widest selector rejects a non-object public expectation" 1 \
  "could not select the widest public-output" \
  -- run_helper llzk_widest_public_input "${workdir}/public-width-malformed"

mkdir -p "${workdir}/public-width-missing-input"
printf '{"out0":"1","out1":"2","out2":"3"}\n' \
  > "${workdir}/public-width-missing-input/NoInput.0.public.json"
expect "widest selector rejects a missing paired input" 1 \
  "widest public-output self-test has no input file" \
  -- run_helper llzk_widest_public_input "${workdir}/public-width-missing-input"

mkdir -p "${workdir}/public-width-empty"
expect "widest selector rejects a directory with no candidates" 1 \
  "could not select the widest public-output" \
  -- run_helper llzk_widest_public_input "${workdir}/public-width-empty"

expect "exact count accepts equality" 0 "" \
  -- run_helper llzk_require_exact_count "test split" 10 10
expect "exact count rejects a smaller value" 1 "got 9, expected exactly 10" \
  -- run_helper llzk_require_exact_count "test split" 9 10
expect "exact count rejects a larger value" 1 "got 11, expected exactly 10" \
  -- run_helper llzk_require_exact_count "test split" 11 10
expect "exact count rejects a non-natural value" 1 "counts must be natural numbers" \
  -- run_helper llzk_require_exact_count "test split" ten 10

expect "e2e headline discriminator wiring is source pinned" 0 "" \
  -- check_e2e_wiring "${script_dir}/e2e.sh"

python3 - "${script_dir}/e2e.sh" "${workdir}/e2e-xor-unreachable.sh" <<'PYEOF'
import pathlib, sys

source = pathlib.Path(sys.argv[1]).read_text()
needle = "for xor_index in 7 8 9; do\n"
if source.count(needle) != 1:
    raise SystemExit("could not construct the Xor32 unreachable-control fixture")
pathlib.Path(sys.argv[2]).write_text(source.replace(needle, needle + "  continue\n", 1))
PYEOF
expect "e2e Xor32 source pin rejects unreachable discriminator calls" 1 \
  "headline e2e file digest mismatch" \
  -- check_e2e_wiring "${workdir}/e2e-xor-unreachable.sh"

python3 - "${script_dir}/e2e.sh" "${workdir}/e2e-xor-wrapped.sh" <<'PYEOF'
import pathlib, sys

source = pathlib.Path(sys.argv[1]).read_text()
start = 'echo "== Xor32 exhaustive output and narrowing self-test =="\n'
end = "# G10 is in two halves.\n"
if source.count(start) != 1 or source.count(end) != 1:
    raise SystemExit("could not construct the Xor32 outside-wrapper fixture")
wrapped = source.replace(start, "if false; then\n" + start, 1)
wrapped = wrapped.replace(end, end + "fi\n", 1)
pathlib.Path(sys.argv[2]).write_text(wrapped)
PYEOF
expect "e2e Xor32 outside-wrapper fixture is valid shell" 0 "" \
  -- bash -n "${workdir}/e2e-xor-wrapped.sh"
expect "e2e Xor32 source pin rejects an unreachable wrapped block" 1 \
  "headline e2e file digest mismatch" \
  -- check_e2e_wiring "${workdir}/e2e-xor-wrapped.sh"

python3 - "${script_dir}/e2e.sh" "${workdir}/e2e-blake-unreachable.sh" <<'PYEOF'
import pathlib, sys

source = pathlib.Path(sys.argv[1]).read_text()
needle = "for blake_index in 0 1 2 3 4 5; do\n"
if source.count(needle) != 1:
    raise SystemExit("could not construct the BLAKE3.G unreachable-control fixture")
pathlib.Path(sys.argv[2]).write_text(source.replace(needle, needle + "  continue\n", 1))
PYEOF
expect "e2e BLAKE3.G source pin rejects unreachable vector preflights" 1 \
  "headline e2e file digest mismatch" \
  -- check_e2e_wiring "${workdir}/e2e-blake-unreachable.sh"

python3 - "${script_dir}/e2e.sh" "${workdir}/e2e-blake-wrapped.sh" <<'PYEOF'
import pathlib, sys

source = pathlib.Path(sys.argv[1]).read_text()
start = 'echo "== BLAKE3.G exhaustive interface self-test =="\n'
end = "# G10 is in two halves.\n"
if source.count(start) != 1 or source.count(end) != 1:
    raise SystemExit("could not construct the BLAKE3.G outside-wrapper fixture")
wrapped = source.replace(start, "if false; then\n" + start, 1)
wrapped = wrapped.replace(end, end + "fi\n", 1)
pathlib.Path(sys.argv[2]).write_text(wrapped)
PYEOF
expect "e2e BLAKE3.G outside-wrapper fixture is valid shell" 0 "" \
  -- bash -n "${workdir}/e2e-blake-wrapped.sh"
expect "e2e BLAKE3.G source pin rejects an unreachable wrapped block" 1 \
  "headline e2e file digest mismatch" \
  -- check_e2e_wiring "${workdir}/e2e-blake-wrapped.sh"

expect "e2e exact counts are literal source pins" 0 "" \
  -- bash -c '
       for assignment in \
         LLZK_EXPECTED_SMT_OK=10 \
         LLZK_EXPECTED_SMT_SKIPPED=9 \
         LLZK_EXPECTED_ARTIFACTS=17 \
         LLZK_EXPECTED_VECTORS=67 \
         LLZK_EXPECTED_FIXTURES=2
       do
         rg --fixed-strings --line-regexp "readonly ${assignment}" "$1/e2e.sh" >/dev/null \
           || exit 1
       done
     ' _ "${script_dir}"

echo
if (( failed > 0 )); then
  echo "FAIL: ${passed} passed, ${failed} failed"
  exit 1
fi
echo "PASS: ${passed} error paths exercised"
