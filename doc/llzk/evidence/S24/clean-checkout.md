# S24 D3 — reproducing Stage 1 from a fresh checkout

R2's exit criterion required this and every review since inherited the omission.
Everything green before today was green on the development worktree, which has
an accumulated `.lake`, a warm Nix store and an `upstream` remote that a stranger
does not have.

**The point of this exercise is not that the gates pass. It is what a stranger
has to discover.** The findings below are the answer; the `PASS` is the control
that says they are the *whole* answer.

## What was run

```bash
git clone --no-local <this repo> /tmp/.../fresh-checkout
cd /tmp/.../fresh-checkout
git remote add upstream git@github.com:Verified-zkEVM/clean.git
```

then the documented path from `CURRENT.md`, and nothing else:

```bash
export LLZK_OPT=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-opt
export LLZK_WITGEN=/nix/store/x2wpfaymqfrvk9gv0jbbd7w1qgxhl1x0-llzk-release-3.0.0/bin/llzk-witgen
export LLZK_SESSION=S24-fresh
bash scripts/llzk/worktree-lock.sh claim "S24 clean-checkout reproduction"
bash scripts/llzk/e2e.sh
```

Cloned at `ccfddd8d`, branch `clean-to-llzk/integration`, toolchain
`leanprover/lean4:v4.30.0`, no `.lake`.

## Findings

### 1. The mathlib build cache is not documented anywhere, and dominates everything

`README.md` says "Clone this repo, and test that everything works by building:
`lake build`". `CURRENT.md`'s reproduce block adds the two LLZK variables and
`e2e.sh`. Neither mentions `lake exe cache get`.

Without it, G1's `lake build --wfail Clean` builds **mathlib from source** — 1837
targets, individual modules taking 200–500 s. That is the single largest cost of
reproducing this project and nothing in the documentation warns about it or says
how to avoid it.

This is invisible from every place it would have been caught:

- the development worktree has had a `.lake` since S00;
- CI does not hit it either, because `leanprover/lean-action@v1` fetches the
  mathlib cache by default — so the one automated consumer of these instructions
  silently does the step the instructions omit.

**Fix:** `CURRENT.md`'s reproduce block should start with `lake exe cache get`,
and say what happens if it is skipped. Recorded rather than silently patched into
the run: the run below is the *documented* path, unaided.

### 2. `git remote add upstream` is required by G0 and documented only as a URL

A fresh clone has `origin` only. `check-pins.sh` then fails with

> no git remote named 'upstream'; this worktree is not the project home (D002)

which is diagnostic but not actionable — it does not say to add the remote or
what URL. `PINS.md` lists `git@github.com:Verified-zkEVM/clean.git` under
"Clean repository" as a fact about the project, not as a setup step. CI has the
step (`Declare the upstream remote`) and so does the S24 packet's clone recipe,
so the knowledge exists in three places, none of which is where someone
reproducing would look.

R4 already hit the *unhandled* version of this and the repair added the message;
G11 has covered the branch since S21. The remaining gap is that the message
tells you what is wrong and not what to do.

**Fix:** one line in `CURRENT.md`'s reproduce block, and the remedy in the
diagnostic.

### 3. The LLZK tools are a bare `/nix/store` path

`CURRENT.md` exports a store path that exists on this machine. A stranger has to
notice `PINS.md` and run the `nix build` there, including the `--max-jobs 0`
discipline and the cache-key requirement. That is documented well in `PINS.md`
and not linked from the step that needs it.

Not a defect in the same class as 1 and 2 — the reproduce block does say "See
`PINS.md` for how to obtain the tools" — but the ordering invites pasting a path
that will not exist.

### 4. A fresh build can fail for reasons that have nothing to do with the code

The first completed build attempt failed here:

```
error: Clean/Gadgets/ByteDecomposition/Theorems.lean:62:4:
       The SAT solver timed out while solving the problem.
```

Line 62 is a `bv_decide`. It is not a flaky proof in the ordinary sense — it is a
proof whose success depends on a **solver time limit**, and therefore on how
loaded the machine is. Another project's `lake build` was running throughout
(62 GB machine at 54–57 GB used, swap full), which is precisely the situation
`CURRENT.md`'s "Known constraints" already names:

> Heavy Nix and Lean builds must not run concurrently on this machine; doing so
> produced a spurious Lean target failure during S00.

This is the second instance of that class, and the first one for which the
mechanism is identified rather than guessed. It matters for reproduction in a way
S00's did not: a stranger on a slower or busier machine can get a **red G1 from a
tree that is correct**, and nothing in the failure says so. The gate is honest —
it fails closed — but the diagnosis is not discoverable from it.

Not a defect this session introduced and not one it fixes. Recorded because D3's
question is "what does a stranger have to discover", and this is on the list.
`bv_decide`'s budget is a candidate for being pinned explicitly rather than left
to the default.

### 5. What worked without any undocumented step

- The worktree lock, on its first real use by something other than its author: a
  fresh checkout has no lock file, `claim` succeeded, and `e2e.sh`'s new
  `require` passed. This is also the shape CI uses (a claim step plus a stable
  `LLZK_SESSION`), so D023's decision to have CI claim rather than be exempted is
  exercised here rather than only argued.
- G11 (30 error paths), G12 and G0 all passed on the fresh checkout before any
  Lean build, in seconds.
- Tool detection, including the `llzk-witgen` provenance-by-co-location check.

## Result

The fresh checkout reaches the same `PASS` line as the development worktree,
with the same counts:

```
PASS: 30 error paths exercised
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
  11 circuit(s), 30 input vector(s), both witgen backends.
  2 renderer fixture(s), syntax only.
  G10a: all 11 + 2 module(s) admitted by --llzk-product-program.
  G10b: 9 module(s) lowered to SMT, 4 out of scope for a declared reason.
exit status: 0
```

at commit `ccfddd8d`, in a checkout that had no `.lake`, no warm Nix store and no
`upstream` remote when it started. R2's exit criterion is met.

**What the run was, exactly, so the claim is not stronger than the evidence.**
The gate phase above is one uninterrupted `e2e.sh` (02:42:52Z → 02:45:39Z). The
Lean build that precedes it was not: it was interrupted twice by this session's
harness and restarted, and failed once on the SAT timeout in finding 4 before
succeeding on retry. `lake` resumes from `.lake`, so the artifact is the same one
an uninterrupted build produces — but "ran start to finish in one command" is not
claimed, because it did not.

Nothing needed to be changed in the tree to make any of this pass. The four
findings are about the *instructions*, not the code, which is the outcome D3 was
looking for and not the one it was guaranteed to get.

## What was fixed as a result

Findings 1 and 2 are closed, in the places someone reproducing would actually
look:

- `CURRENT.md`'s reproduce block is now four numbered steps in dependency order,
  starting with `git remote add upstream` and `lake exe cache get`, and says what
  happens if the cache step is skipped.
- `check-pins.sh`'s missing-`upstream` diagnostic now prints the remedy — the
  exact `git remote add` line — rather than only the diagnosis. G11 still covers
  the branch.

Findings 3 and 4 are recorded and not fixed here. 3 is a documentation ordering
question `PINS.md` already answers. 4 is a property of a `bv_decide` in Clean's
own gadget code, and pinning a solver budget is a change to Clean, with its own
review.
