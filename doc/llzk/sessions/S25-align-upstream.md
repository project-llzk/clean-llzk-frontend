# S25 — Align with upstream Clean and Lean 4.32.2

Status: proposed
Depends on: A4 (landed, `fc22da88`); nothing else
Base integration commit: `89a6f4e8`
Worktree: `/home/alh/LLZK/clean-llzk-frontend`
Branch: a **new** branch off `clean-to-llzk/integration` — see "Branch" below

## Objective

Move this backend from Clean `1e563b9c` / Lean 4.30.0 to upstream Clean
`0e53b9f2` / Lean 4.32.2, with all twelve gates green, and record what the
witness-IR rewrite means for D011.

Nothing else. No new capability, no new circuit, no gap closed. The point of
doing it alone is that the gates then say exactly one thing: *the bump did or did
not break the backend.*

## Must read

- `AGENTS.md` (repository root, i.e. `CLAUDE.md`)
- `doc/llzk/CURRENT.md`
- `doc/llzk/PINS.md`
- `doc/llzk/GATES.md`
- `doc/llzk/DECISIONS.md` — **D011 and D025 especially**
- `doc/llzk/GAPS.md`

## Why this comes first, and why it is not optional

The plan before this packet was to add two capability increments at the current
pin: a recognizer for the bit-decomposition shape
`ofNat (mod (div (val x) (const 2^i)) (const 2))`, and then bitwise
`land`/`lor`/`lxor`. **Both would have been thrown away**, and D025 records why:

- upstream **deleted `Witgen.NExpr`**, the unbounded-`ℕ` sort D011's entire
  argument is about, and replaced it with `U64Expr` — bounded, wrapping modulo
  `2^64`;
- upstream added **`VExpr.bitsOf {n} (x : FExpr F)`** and `BExpr.bit x i`, so bit
  decomposition is a *constructor* rather than a pattern to recognise;
- `land`/`lor`/`lxor` now live on `U64Expr`, so an increment written against
  `NExpr` targets a type that no longer exists.

So the increments are not merely early, they are aimed at the wrong IR.

## Branch

Do **not** do this on `clean-to-llzk/integration`. Branch:

```bash
bash scripts/llzk/worktree-lock.sh claim "S25 bump to 4.32.2"
git switch -c clean-to-llzk/bump-4.32.2
```

Two reasons. The bump is the kind of change that can be half-done for a while,
and `integration` should stay green and publishable throughout — PR #1 is open
against the fork's `main` and CI runs on it. And if the bump turns out to cost
more than expected, abandoning a branch is free.

## The facts, measured, so they are not rediscovered

Verified 2026-08-04 against `upstream/main`:

| | value |
|---|---|
| upstream head | `0e53b9f2`, "Merge pull request #443 from Verified-zkEVM/bump-lean-4.32.2" |
| merged | 2026-08-04 — the same day this packet was written |
| toolchain | `leanprover/lean4:v4.32.2` (upstream has no tags or releases; `main` *is* the release) |
| commits ahead of `1e563b9c` | 70 |
| `Clean/Circuit/` churn | +878 / −194 across 15 files |
| `WitnessIR.lean` | +213 |
| `WitnessIRSugar.lean` | +310 |

What changed in the witness IR, constructor by constructor:

- **`FExpr`**: `envGet` **removed**; `ofNat` → **`ofU64`**; **`lor` added**.
- **`NExpr` deleted**, replaced by **`U64Expr`** — `const (n : UInt64)`, `val`,
  `idx`, `localVar`, `add`, `mul`, `div`, `mod`, `land`, `lor`, `lxor`, `shiftL`,
  `shiftR`, `ite`. Docstring: *"All operations wrap modulo `2^64`."*
- **`BExpr` is new** as a sort of its own: `true`, `false`, `feq`, `neq`, `lt`,
  `flt`, `bit (x : FExpr F) (i : ℕ)`, `not`, `and`. `ite` on both `FExpr` and
  `U64Expr` now takes a `BExpr`.
- **`VExpr`** gains `mapRange`, `envRange`, **`bitsOf`**, keeps `lit`, `append`.
- **`Step`** is `letF` / `letU` (was `letF` / `letN`).

## Allowed scope

- `lean-toolchain`, `lake-manifest.json`, `lakefile.lean` as the bump requires.
- Everything under `Clean/Backend/LLZK/`.
- `scripts/llzk/check-pins.sh` — `clean_base` and `expected_toolchain`.
- `doc/llzk/{CURRENT,PINS,DECISIONS,GAPS,ROADMAP}.md`.
- `.github/workflows/ci.yml` only if the toolchain pin appears in it.

**Not** `Clean/` outside `Clean/Backend/LLZK/`. G0 enforces this, and the
enforcement is the point: the base moves by *re-pinning*, not by editing Clean.

## Deliverable 1 — the merge, and a base that G0 accepts

```bash
git fetch upstream
git merge upstream/main          # or rebase; either is fine, record which
```

Then `check-pins.sh` needs three edits, and they are the whole of G0's contract
with this session:

- `clean_base` → `0e53b9f2…` (full sha)
- `expected_toolchain` → `leanprover/lean4:v4.32.2`
- the byte-identity allowlist is unchanged — `Clean.lean` and `Clean/Test.lean`
  are still the only registration exceptions

Then `lake exe cache get` before anything else, or mathlib builds from source.

## Deliverable 2 — make the backend compile again

Expect the breakage to be concentrated, and expect it to be *loud*:

- **`Witness.lean`** — `describeFExpr` is exhaustive over `FExpr` and
  `describeNExpr` over `NExpr`. The first loses `envGet`, gains `lor`, and renames
  `ofNat`; the second is about a type that no longer exists. This is the design
  working (D009: "exhaustiveness is what makes adding a constructor a compile
  error in this module rather than a silent unsupported"), so do not paper over
  it — every new constructor gets a diagnostic that names it and says what
  supporting it would take.
- **`FieldExpr.ofFExpr`** matches `.ofNat (.mod (.val x) (.const c))` and
  `.ofNat (.div …)`. Those patterns are gone. **Deliverable 2 keeps the accepted
  set the same size** — translate the two shapes to their `U64Expr` equivalents
  and reject everything else, exactly as now. Widening the accepted set is S26.
- **`WitnessCheck.lean`** — `WExpr.ofWitgen` matches the same two shapes, and
  `eval_ofWitgen` is stated over `Witgen.FExpr.eval`, which moved.
- **`Differential.lean`** — rides on `FlatOperation.witgen`; check its signature.
- General churn: two Lean minors and a mathlib bump. Our proofs lean on
  `Array.mem_filterMap`, `Array.isEmpty_iff`, `zipIdx`, `flatMap`,
  `List.isPerm`, `Nat.eq_of_not_ne`. Expect renames.

**Hold the line on scope.** If a construct is newly expressible, reject it with a
diagnostic and note it in the handoff. The temptation to "just support `bitsOf`
while I'm here" is how a bump becomes unreviewable.

## Deliverable 3 — record what this does to D011

D011 says natural arithmetic must be matched *whole* because `NExpr` is unbounded.
Against `U64Expr` that argument does not hold: the sort is fixed-width, so
structural lowering becomes possible, which is what S26 is for.

But **it is replaced by a new problem, not freed of one**, and D025 must say so
in this session's words after the bump is real:

> a `u64` does not fit in a babybear felt. `p_babybear ≈ 2^31`, and `U64Expr`
> wrapping modulo `2^64` is not reduction modulo `p`. For **bn254** a `u64` fits
> comfortably and the operations are near-direct; for babybear, koalabear and
> mersenne31 they are not, and a faithful lowering needs limbs.

Write down which of the six registry fields can host a `u64` directly. That table
is S26's first design input.

## Non-goals

- Any widening of the accepted subset — that is S26.
- `land`/`lor`/`lxor`, `bitsOf`, `ite`, `let`-steps.
- Upstreaming gadgets to the fork — that is S27.
- Publishing or a PR. `integration` is untouched by this branch.

## Acceptance gates

All of them, unchanged, from a tree that has claimed the lock:

```bash
export LLZK_SESSION=S25
export LLZK_OPT=…/bin/llzk-opt LLZK_WITGEN=…/bin/llzk-witgen
bash scripts/llzk/worktree-lock.sh claim "S25 bump to 4.32.2"
bash scripts/llzk/e2e.sh
```

Expected, and **identical to today** — that is the acceptance criterion:

```
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
  12 circuit(s), 33 input vector(s), both witgen backends.
```

Two gates deserve attention because they are the ones a bump can quietly weaken:

- **G2**, the goldens. If the emitted text changes, *stop and explain why* before
  regenerating. A bump has no business changing the output; if it does, that is a
  finding, not a fixture to refresh.
- **G8**, the negative fixtures. Diagnostic messages are pinned with
  `#guard_msgs`. New constructor names will change some of them, which is correct
  — but a fixture that changes from "rejected for reason X" to "rejected for
  reason Y" needs reading, not accepting.

Also re-run the axiom check; the bump must not add axioms:

```
#print axioms LLZK.spec_of_compile
#print axioms LLZK.ofSource_lookups_iff
```

## Evidence

`doc/llzk/evidence/S25/`:

- `gates.txt` — the full run, exit status, commit under test
- `witness-ir-diff.md` — the constructor-by-constructor change, and the
  u64-per-field table from Deliverable 3
- `goldens.md` — either "no emitted text changed" or the diff with an explanation

## Handoff

- Changes made:
- Decisions made:
- Deviations:
- Blockers:
- Resulting commit:
- Exact next action: `doc/llzk/sessions/S26-witness-u64.md`
