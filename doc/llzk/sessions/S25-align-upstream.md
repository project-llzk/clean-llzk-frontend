# S25 — Align with upstream Clean and Lean 4.32.2

Status: complete locally on 2026-08-21; not pushed or integrated
Depends on: R7 (landed, `97390fac`); nothing else
Base public-readiness commit: `805f2a07`
Worktree: `/home/alh/LLZK/clean-llzk-frontend`
Branch: `clean-to-llzk/bump-4.32.2`, from the complete local public-readiness
stack rather than the older integration tip

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

Verified 2026-08-04 against `upstream/main`; the remote head was checked again
on 2026-08-21 and was unchanged:

| | value |
|---|---|
| upstream head | `0e53b9f2`, "Merge pull request #443 from Verified-zkEVM/bump-lean-4.32.2" |
| merged | 2026-08-04 — the same day this packet was written |
| toolchain | `leanprover/lean4:v4.32.2` (upstream has no tags or releases; `main` *is* the release) |
| commits ahead of `1e563b9c` | 70 |
| `Clean/Circuit/` churn | +878 / −194 across 15 files |
| `WitnessIR.lean` | +213 |
| `WitnessIRSugar.lean` | +310 |

What changed in the witness IR, constructor by constructor. **R7 checked this
list against the actual upstream file and corrected three entries** (R7-10) —
write the new exhaustive matches from `upstream/main`'s
`Clean/Circuit/WitnessIR.lean`, not from here:

- **`FExpr`**: `envGet` **removed**; `ofNat` → **`ofU64`**. (An earlier version
  said "`lor` added" — upstream `FExpr` is
  expr/const/localVar/add/mul/inv/ofU64/ite/listGet/dataGet/hintGet, no `lor`.)
- **`NExpr` deleted**, replaced by **`U64Expr`** — `const (n : UInt64)`, `val`,
  `idx`, `localVar`, `add`, `mul`, `div`, `mod`, `land`, `lor`, `lxor`, `shiftL`,
  `shiftR`, `ite`. Docstring: *"All operations wrap modulo `2^64`."*
- **`BExpr`** existed at our pin already (`true`, `false`, `feq`, `neq`, `lt`,
  `not`, `and`, and `ite` already took one); what is new is **`flt`** and
  **`bit (x : FExpr F) (i : ℕ)`**.
- **`VExpr`** keeps `lit`, `append`, `mapRange` (already at our pin) and gains
  **`envRange`** and **`bitsOf`**.
- **`Step`** is `letF` / `letU` (was `letF` / `letN`); locals are `F ⊕ UInt64`
  (was `F ⊕ ℕ`).

**And the change that is not a rename (R7-08, SEVERE):** `U64Expr.val` is
**truncating** — `UInt64.ofNat (FiniteField.val (x.eval ctx))`, "ZMod.val
truncated to 64 bits" — where the deleted `NExpr.val` was exact. See the new
Deliverable 2a below; this is the one place "translate exactly and re-prove"
is not available.

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
  `describeNExpr` over `NExpr`. The former must lose `envGet`, rename `ofNat` to
  `ofU64`, and stay exhaustive over the upstream `FExpr`; the latter must become
  an exhaustive `U64Expr` description, including `land`/`lor`/`lxor` and shifts.
  `BExpr`, `VExpr.envRange`, and `VExpr.bitsOf` must likewise reach explicit
  acceptance or rejection paths. This is the design working (D009:
  "exhaustiveness is what makes adding a constructor a compile error in this
  module rather than a silent unsupported"), so do not paper over it — every
  constructor gets a diagnostic that names it and says what supporting it would
  take.
- **`FieldExpr.ofFExpr`** matches `.ofNat (.mod (.val x) (.const c))` and
  `.ofNat (.div …)`. Those patterns are gone. **Deliverable 2 keeps the accepted
  set the same size** — translate the two shapes to their `U64Expr` equivalents
  and reject everything else, exactly as now. Widening the accepted set is S26.
- **`WitnessCheck.lean`** — `WExpr.ofWitgen` matches the same two shapes.
  `eval_ofWitgen` did not "move"; its subject changed semantics — see
  Deliverable 2a, which owns this.
- **`Differential.lean`** — rides on `FlatOperation.witgen`; check its signature.
- General churn: two Lean minors and a mathlib bump. Our proofs lean on
  `Array.mem_filterMap`, `Array.isEmpty_iff`, `zipIdx`, `flatMap`,
  `List.isPerm`, `Nat.eq_of_not_ne`. Expect renames.
- **`circuit_norm` was re-keyed** (R7-10): upstream removed `@[circuit_norm]`
  from `ProvableStruct.eval`/`eval.go` and `toComponents`, added the
  `StructEvalSimprocs` machinery, new `@[simp, circuit_norm]`
  `fromNat_zero`/`fromNat_one`, Witnessable projection lemmas and a `u64Wrap`
  simproc. `Test/Soundness.lean` and `Test/Lookups.lean` are this backend's
  `circuit_norm` consumers — their proofs can break or close differently with
  no witness-IR involvement at all. Budget for it.

## Deliverable 2a — the `val` truncation, as a recorded decision (R7-08)

For the recognized shape `ofU64 (div (val x) (const c))`, upstream now
evaluates `fromNat ((val x % 2^64) / c)` where the backend's reading
(`WExpr.uintdiv`) means `fromNat (val x / c)`. These differ whenever
`val x ≥ 2^64` — impossible on babybear/koalabear/mersenne31/goldilocks,
reachable exactly on **bn254 and grumpkin**. (`mod` survives untouched only
because `256 ∣ 2^64`.) So after the prescribed translation, `eval_ofWitgen` as
stated over generic `[FiniteField F]` is **false**, and no gate will say so:
every div/mod corpus entry is babybear, where truncation is invisible.

The scope-preserving move, which this packet prescribes: restate
`eval_ofWitgen` (and whatever of the G9 witness chain rests on it) with the
hypothesis `FiniteField.size F ≤ 2^64`, and record a decision entry (D026)
saying out loud that the witness meaning theorem no longer covers bn254 and
grumpkin for `val`-rooted div/mod witnesses — those fields' registry entries
stay, and circuits without such witnesses are unaffected. The alternative
(changing `WExpr` semantics to truncate) touches D017's reading and the G2
goldens, and belongs to S26's design question if taken at all. Either way the
acceptance criterion below reads "gates identical" and **cannot see this** —
the handoff and D026 are where it must be visible.

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

— with one recorded exception the gates cannot express: Deliverable 2a's
restatement of `eval_ofWitgen` is a semantic weakening on two fields, visible
only in the theorem statement and D026. "All gates green" plus "no decision
entry written" is a **failed** S25, not a passed one (R7-08).

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

- Changes made: fetched and conflict-free merged upstream `0e53b9f2`; moved to
  Lean 4.32.2; adapted the backend from `NExpr`/`ofNat`/`letN` to
  `U64Expr`/`ofU64`/`letU`; made `flt`, `bit`, `envRange`, `bitsOf`, and `letU`
  explicit red paths; repaired the 4.32 overlapping-instance linter finding
  without suppression; rechecked the VeIR seam.
- Decisions made: D026 preserves the narrow accepted syntax and adds
  `FiniteField.size F ≤ 2^64` to `WExpr.eval_ofWitgen`. The theorem covers the
  four small registry fields, not bn254/grumpkin `val`-rooted div/mod witnesses.
  D003 remains non-blocking because its measured dialect gap remains even though
  Clean's toolchain mismatch lapsed.
- Deviations: none from the capability boundary. The packet's old direct S26
  handoff is superseded by the public-readiness roadmap's prepared L0 LLZK-pin
  review.
- Blockers: none.
- Resulting implementation commit:
  `6ccca6f862f3fdb13c8d418849aacb98e9841287`.
- Evidence: `doc/llzk/evidence/S25/`; G0-G12 passed, 12 circuits, 33
  vectors on both witgen backends, 2 renderer fixtures, G10a 14/14, G10b 10/4,
  G11 53; the theorem audit has no `sorryAx`.
- Exact next action: `doc/llzk/sessions/L0-review-llzk-pin.md`.
