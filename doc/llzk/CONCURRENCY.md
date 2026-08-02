# One writer per worktree, and how to check

`ORCHESTRATION.md` §7 already says this:

> One active writing session owns one worktree and one branch.
> Two sessions must never edit the same worktree concurrently.
> Concurrent work is integrated through commits, not through shared
> uncommitted files.

Nothing enforced it, and on 2026-08-01 it was violated three times in one day.

## What it cost

| Occasion | Damage |
|---|---|
| R4 | Both reviewers had the tree rewritten under them mid-review and had to re-verify every finding against a moving target. |
| S21 | R5's packet declared the tree frozen. S21 checked, saw a clean tree and no findings file, concluded R5 had not started, and edited. R5 was running; it wrote its findings between two of S21's edits. |
| S22 | A session ran `git add -A` and swept another session's entire X1 repair — private `Config` constructor, `unsafeWithTables`, D022, G12, `check-unsafe-config.sh` — into a commit titled and described for X2. Both sessions also independently withdrew the *same* false docstring. |

Nothing was lost in any of the three. What was lost is worse than a file: history
that says what happened, repairs that happen once, and gate evidence that can be
tied to a commit. S22's evidence file had to carry a caveat saying its `PASS`
could not be attributed to its own commit.

Note the second row especially. S21 *did* check, and the check was
race-prone — "clean tree, no findings file" is not a lock, and the answer went
stale between reading it and acting on it.

## The check

```bash
bash scripts/llzk/worktree-lock.sh status                 # who owns it
bash scripts/llzk/worktree-lock.sh claim "S23 X1 closure" # take it, or find out who has it
bash scripts/llzk/worktree-lock.sh require                # assert before writing
bash scripts/llzk/worktree-lock.sh reclaim "S24"          # take one whose owner is gone
bash scripts/llzk/worktree-lock.sh release                # give it back
```

Identity is `LLZK_SESSION` when set, and otherwise the POSIX session id, so a
session recognises its own lock from any subshell. Liveness **fails closed**: an
owner that cannot be checked counts as live, because treating "cannot tell" as
"dead" is the failure this guards against. A stale lock — a numeric session
leader that is provably gone — is *reported* and taken only by `reclaim`, never
by `claim`. A genuinely stuck lock is cleared by deleting
`.llzk-worktree-owner`, which is a deliberate act and gitignored.

## Set `LLZK_SESSION` if you are an agent session

The POSIX session id is the right identity for a person at a terminal, where
every command shares one session for as long as the terminal lives. It is the
wrong one under a harness that runs each command with `setsid`: there the session
leader *is* the command, so the identity dies when the command returns.

S24 found this by running the two lines the packet told it to run, in that order:

```
$ bash scripts/llzk/worktree-lock.sh claim "S24 finish Stage 1"
worktree claimed by session 1405618 — S24 finish Stage 1
$ bash scripts/llzk/worktree-lock.sh require
error: this process does not hold the worktree lock
$ bash scripts/llzk/worktree-lock.sh status
stale lock from session 1405618 — S24 finish Stage 1; reclaimable
```

So the lock did not work for the kind of session it was written for. Worse than
failing `require`: `claim` used to take a stale lock silently, so a second agent
session would have been told the tree was free — the S22 collision, unchanged,
now with a lock file to point at afterwards. Two things follow, and both are in
the script:

- `reclaim` is split out of `claim`, so ownership never transfers without
  someone saying it should;
- every agent session sets `LLZK_SESSION` to a stable label, inline on each
  command, because the harness does not carry exports between them:

```bash
LLZK_SESSION=S24 bash scripts/llzk/e2e.sh
```

This is discoverable rather than remembered: `require`'s refusal names
`LLZK_SESSION` and prints the identity it computed for the current process.

It is advisory. It cannot stop a determined writer and does not try. It makes
ownership visible and checkable, which is the same treatment
`Config.unsafeWithTables` got in S22: the unsafe path stays available, and
becomes loud.

## If the worktree is taken

Do not wait and do not write anyway. Take your own:

```bash
git worktree add -b clean-to-llzk/<topic> ../clean-llzk-<topic> "$(git rev-parse HEAD)"
```

and integrate through commits. The one real cost is that a fresh worktree has no
`.lake`, and a full build is expensive; copying `.lake/packages` across with
`cp -al` gets the dependency oleans for free and leaves only Clean's own modules
to rebuild. Weigh that against a fourth collision.

## Wired into the gate, as of S24

`e2e.sh` calls `require` before G11 and refuses to run without the lock. It was
deliberately left unwired when written, because doing so would have failed the
gate run of a session that was mid-repair and had claimed nothing; that session
finished, so S24 wired it.

`e2e.sh` is the right place. It is not a read-only check: G2 deletes and rebuilds
`.lake/llzk`, and the evidence a run produces is only attributable to a commit if
one session owned the tree while it ran. S22's evidence file had to carry a
caveat saying its `PASS` could not be attributed to its own commit.

The consequence, accepted knowingly: **every** gate run must claim first,
including CI.

### CI claims the lock; it is not exempted

The alternative was to have `require` treat a non-interactive environment as
exempt. Rejected. An exemption needs a predicate for "no contention here", and
every predicate available — no tty, non-interactive, `CI=true` — is also true of
the agent sessions on the development machine, which are exactly the writers that
collided three times in one day. A mis-set exemption is invisible: the gate
passes.

The `llzk-e2e` job therefore has a claim step, and a job-level
`LLZK_SESSION: ci-${{ github.run_id }}-${{ github.run_attempt }}` because each
`run:` block is a fresh POSIX session. On a fresh ephemeral checkout the claim
always succeeds, so this is two lines and no new failure mode; it also means CI
exercises the same path a developer does rather than a bypass around it.

`llzk-harness` needs nothing: it runs `check-pins.sh`, `test-scripts.sh` and
`check-confinement.sh` directly, none of which write to the worktree.
