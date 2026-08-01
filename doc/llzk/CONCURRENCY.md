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
bash scripts/llzk/worktree-lock.sh release                # give it back
```

Identity is the POSIX session id, so a session recognises its own lock from any
subshell. Liveness **fails closed**: a lock is reclaimed only when its owner is a
numeric session leader that is provably gone. An owner that cannot be checked
counts as live, because treating "cannot tell" as "dead" is the failure this
guards against. A genuinely stuck lock is cleared by deleting
`.llzk-worktree-owner`, which is a deliberate act and gitignored.

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

## Not yet wired into a gate

Deliberately. Wiring `require` into `e2e.sh` would fail the gate run of any
session that has not claimed the lock — including, at the time this was written,
one that was mid-repair and had claimed nothing. Wiring it is a one-line change
to `e2e.sh` and belongs to the first session that owns the tree uncontested.
Until then this is a tool sessions call, not a gate that fails them.
