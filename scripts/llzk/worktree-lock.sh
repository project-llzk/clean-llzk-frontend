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
#   reclaim [LABEL] [--from ID]
#                   take a lock whose owner is gone (a deliberate act). Without
#                   --from, only a numeric owner this machine can prove dead;
#                   with it, any owner, and naming it is the proof you looked.
#   release         give it up (only the holder may)
#   status          who holds it, if anyone
#   require         succeed only if this process holds it
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
lock="${repo_root}/.llzk-worktree-owner"

# shellcheck source=scripts/llzk/lib.sh
source "${script_dir}/lib.sh"

# Identity is LLZK_SESSION when set, and otherwise the POSIX *session id* — not
# $$ or $PPID, because a session invokes this from many short-lived subshells and
# any per-invocation PID would make a session fail to recognise its own lock.
#
# **Set LLZK_SESSION if you are an agent harness.** The POSIX session is the
# right identity for a person at a terminal, where every command shares one
# session for as long as the terminal lives. It is the wrong one under a harness
# that runs each command with `setsid`: there the session leader is the
# *command*, so the identity dies when the command returns. Claiming the lock
# then leaves a record whose owner is already gone — `require` stops recognising
# it on the very next command, and, before `reclaim` was split out below, the
# next session silently took the tree. That is the S22 collision exactly, from a
# session that did consult the lock. See doc/llzk/CONCURRENCY.md.
#
# LLZK_SESSION is also what lets this script be tested.
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
# means held.
lock_is_live() {
  local id; id="$(owner_id)"
  [[ -n "${id}" ]] || return 1
  [[ "${id}" == "$(me)" ]] && return 0
  lock_owner_is_opaque && return 0
  kill -0 "${id}" 2>/dev/null
}

# Whether liveness is decidable for the recorded owner at all. It is not for an
# id that came from LLZK_SESSION, which is every agent session and CI.
#
# **R6 found that this made `reclaim` dead code for exactly the identities D023
# introduced it for.** `lock_is_live` answers "live" for an opaque owner, so
# `claim` printed the live-holder refusal, `status` reported the lock as held,
# and `reclaim` refused with "is live; reclaim is only for a lock whose owner is
# gone" -- forever. The only way out was `rm`, which D023 does not mention and
# CURRENT.md's "claim the worktree first" walks straight into. G11 did not see it
# because all three of its stale-lock cases record a *numeric* owner (999999),
# which is the one case that did work.
#
# The fix is not to guess liveness. It is to let the operator supply the missing
# observation: `reclaim --from <id>` takes a lock whose recorded owner is `<id>`,
# and having to copy that id out of the refusal message is the deliberate act.
# An accident cannot produce it, which is the property `claim` needed and did not
# have.
lock_owner_is_opaque() {
  local id; id="$(owner_id)"
  [[ -n "${id}" ]] && [[ ! "${id}" =~ ^[0-9]+$ ]]
}

take_it() {
  printf '%s\n%s\n%s\n' "$(me)" "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${lock}"
  echo "worktree claimed by session $(me) — $1"
}

case "${1:-status}" in
  claim)
    label="${2:-unlabelled session}"
    if [[ -f "${lock}" ]] && [[ "$(owner_id)" != "$(me)" ]]; then
      if lock_is_live; then
        # The exit route differs by whether liveness was *decided* or merely
        # assumed, and saying so is the whole of R6's repair: before it, an
        # opaque owner produced this message, whose only advice is "wait", for a
        # lock that nothing would ever release.
        if lock_owner_is_opaque; then
          llzk_fail "the worktree is held by session $(owner_id) — $(owner_label), since $(owner_since).
Do not write here. That id came from LLZK_SESSION, so this machine cannot tell
whether the session is still running; it is treated as held. Either wait for it
to release, take your own worktree:
  git worktree add -b <branch> ../<dir> \$(git rev-parse HEAD)
and integrate through commits, per ORCHESTRATION.md §7 — or, if you know that
session is finished, displace it by name:
  bash scripts/llzk/worktree-lock.sh reclaim '<what you are doing>' --from '$(owner_id)'"
        fi
        llzk_fail "the worktree is held by session $(owner_id) — $(owner_label), since $(owner_since).
Do not write here. Either wait for it to release, or take your own worktree:
  git worktree add -b <branch> ../<dir> \$(git rev-parse HEAD)
and integrate through commits, per ORCHESTRATION.md §7."
      fi
      # A stale lock is *reported*, never taken silently. Taking it silently is
      # how the lock failed to protect the sessions it was written for: an agent
      # harness that runs each command in its own POSIX session leaves a record
      # whose owner is dead on arrival, so the next session saw a free tree and
      # wrote -- the S22 collision exactly, this time with a lock file to point
      # at afterwards. `reclaim` is the deliberate act, in the same spirit as
      # deleting the file.
      llzk_fail "a stale lock is recorded for session $(owner_id) — $(owner_label), since $(owner_since).
Its owner cannot be found, but 'finished' and 'invisible from here' are the same
observation, so it is not taken for you. If that session is really done, say so:
  bash scripts/llzk/worktree-lock.sh reclaim '<what you are doing>'
If it is your own lock from an earlier command, you are not setting
LLZK_SESSION -- see the note at the top of this script."
    fi
    take_it "${label}"
    ;;
  reclaim)
    label="unlabelled session"
    from=""
    shift || true
    while (( $# > 0 )); do
      case "$1" in
        --from) from="${2:-}"; shift 2 || llzk_fail "--from needs the recorded owner id" ;;
        *) label="$1"; shift ;;
      esac
    done
    if [[ -f "${lock}" ]] && [[ "$(owner_id)" != "$(me)" ]]; then
      if [[ -n "${from}" ]]; then
        # An explicit owner is the observation the script cannot make. It has to
        # be the *recorded* one, so a stale --from from an earlier session cannot
        # displace a holder that arrived since.
        [[ "${from}" == "$(owner_id)" ]] || llzk_fail "--from ${from} does not match the recorded \
owner $(owner_id) — $(owner_label). The lock changed hands since you read it; read it again."
      elif lock_owner_is_opaque; then
        llzk_fail "session $(owner_id) — $(owner_label) holds the lock, since $(owner_since), and \
its liveness cannot be decided here: the id came from LLZK_SESSION, not from a process this
machine can look up. If you know that session is done, say which one you are displacing:
  bash scripts/llzk/worktree-lock.sh reclaim '<what you are doing>' --from '$(owner_id)'"
      elif lock_is_live; then
        llzk_fail "session $(owner_id) — $(owner_label) is live; reclaim is only for a lock whose owner is gone"
      fi
    fi
    # `[[ ... ]] && echo` would exit 1 here under `set -e` when there is no lock
    # to reclaim, so reclaiming a free tree would fail after writing the file.
    if [[ -f "${lock}" ]] && [[ "$(owner_id)" != "$(me)" ]]; then
      echo "note: reclaiming a stale lock from session $(owner_id) — $(owner_label)"
    fi
    take_it "${label}"
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
    if lock_owner_is_opaque && [[ "$(owner_id)" != "$(me)" ]]; then
      # Not "held" flatly: liveness was never observed, and reporting an
      # assumption as a fact is what left R6 with no documented way forward.
      echo "worktree held by session $(owner_id) — $(owner_label), since $(owner_since); \
liveness undecidable (LLZK_SESSION id), reclaimable with --from '$(owner_id)'"
    elif lock_is_live; then
      echo "worktree held by session $(owner_id) — $(owner_label), since $(owner_since)"
    else
      echo "stale lock from session $(owner_id) — $(owner_label), since $(owner_since); reclaimable"
    fi
    ;;
  require)
    lock_is_live && [[ "$(owner_id)" == "$(me)" ]] \
      || llzk_fail "this process does not hold the worktree lock (it is $(
             [[ -f "${lock}" ]] && echo "held by $(owner_id) — $(owner_label)" || echo "free")).
Run:
  bash scripts/llzk/worktree-lock.sh claim '<what you are doing>'
If you did claim it, in an earlier command, then your identity is not stable
across commands: export LLZK_SESSION to the same value in both, or pass it
inline. This process is '$(me)'."
    echo "worktree lock: held"
    ;;
  *) llzk_fail "usage: $0 {claim [LABEL]|reclaim [LABEL]|release|status|require}" ;;
esac
