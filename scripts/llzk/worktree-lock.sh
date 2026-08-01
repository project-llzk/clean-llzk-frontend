#!/usr/bin/env bash
# Advisory ownership lock for the integration worktree.
#
# ORCHESTRATION.md §7 says "one active writing session owns one worktree and one
# branch" and "concurrent work is integrated through commits, not through shared
# uncommitted files". Nothing enforced it, and on 2026-08-01 it was violated
# three times in one day:
#
#   R4  — both reviewers had the tree rewritten under them mid-review.
#   S21 — R5's frozen tree was edited while R5 was running.
#   S22 — a session ran `git add -A` and swept another session's entire X1
#         repair into a commit titled for X2, and both sessions independently
#         withdrew the same false docstring.
#
# The cost is not hypothetical: misattributed history, duplicated repairs, and
# gate evidence that cannot be tied to a commit.
#
# This is advisory by design. It cannot stop a determined writer and does not
# try; it makes ownership *visible and checkable* so that a session which is
# about to write knows whether it may, the same treatment `unsafeWithTables`
# got in S22.
#
#   claim [LABEL]   take the lock, or fail naming the current holder
#   release         give it up (only the holder may)
#   status          who holds it, if anyone
#   require         succeed only if this process holds it
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
lock="${repo_root}/.llzk-worktree-owner"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"

# Identity is the POSIX *session id*, not $$ or $PPID: a session invokes this
# from many short-lived subshells, and any per-invocation PID would make a
# session fail to recognise its own lock. The session leader is also a usable
# liveness probe, so a crashed session leaves a stale lock that is reclaimable
# rather than wedging the worktree forever.
#
# LLZK_SESSION overrides it, which is what lets this script be tested.
me() { echo "${LLZK_SESSION:-$(ps -o sid= -p $$ | tr -d ' ')}"; }
owner_id() { [[ -f "${lock}" ]] && sed -n '1p' "${lock}" || true; }
owner_label() { [[ -f "${lock}" ]] && sed -n '2p' "${lock}" || true; }
owner_since() { [[ -f "${lock}" ]] && sed -n '3p' "${lock}" || true; }

# A lock is live if its owner is this session, or if the recorded owner cannot be
# *proved* dead.
#
# Fails closed on purpose. Liveness is only decidable when the recorded id is a
# numeric session leader; an id set through LLZK_SESSION is opaque. Treating
# "cannot tell" as dead would let any session reclaim any lock it does not
# understand, which is the failure this script exists to prevent -- so unknown
# means held, and a genuinely stuck lock is removed by deleting the file, which
# is a deliberate act.
lock_is_live() {
  local id; id="$(owner_id)"
  [[ -n "${id}" ]] || return 1
  [[ "${id}" == "$(me)" ]] && return 0
  [[ "${id}" =~ ^[0-9]+$ ]] || return 0
  kill -0 "${id}" 2>/dev/null
}

case "${1:-status}" in
  claim)
    label="${2:-unlabelled session}"
    if lock_is_live && [[ "$(owner_id)" != "$(me)" ]]; then
      llzk_fail "the worktree is held by session $(owner_id) — $(owner_label), since $(owner_since).
Do not write here. Either wait for it to release, or take your own worktree:
  git worktree add -b <branch> ../<dir> \$(git rev-parse HEAD)
and integrate through commits, per ORCHESTRATION.md §7."
    fi
    if [[ -f "${lock}" ]] && ! lock_is_live; then
      echo "note: reclaiming a stale lock from session $(owner_id) — $(owner_label)"
    fi
    printf '%s\n%s\n%s\n' "$(me)" "${label}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${lock}"
    echo "worktree claimed by session $(me) — ${label}"
    ;;
  release)
    if [[ ! -f "${lock}" ]]; then echo "no lock held"; exit 0; fi
    if lock_is_live && [[ "$(owner_id)" != "$(me)" ]]; then
      llzk_fail "session $(owner_id) — $(owner_label) holds the lock; only the holder may release it"
    fi
    rm -f "${lock}"; echo "worktree released"
    ;;
  status)
    if [[ ! -f "${lock}" ]]; then echo "worktree is free"; exit 0; fi
    if lock_is_live; then
      echo "worktree held by session $(owner_id) — $(owner_label), since $(owner_since)"
    else
      echo "stale lock from session $(owner_id) — $(owner_label), since $(owner_since); reclaimable"
    fi
    ;;
  require)
    lock_is_live && [[ "$(owner_id)" == "$(me)" ]] \
      || llzk_fail "this process does not hold the worktree lock; run: bash scripts/llzk/worktree-lock.sh claim '<what you are doing>'"
    echo "worktree lock: held"
    ;;
  *) llzk_fail "usage: $0 {claim [LABEL]|release|status|require}" ;;
esac
