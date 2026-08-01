# S01 — Provision current LLZK 3.0 tools

Status: accepted  
Depends on: S00  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Make pinned LLZK 3.0 `llzk-opt` and `llzk-witgen` reproducibly available.

## Acceptance gates

- Both tools answer their smoke-test commands: PASS.
- `bash scripts/llzk/doctor.sh --require-llzk`: PASS.
- The stale installed LLZK 2.0 package cannot satisfy the doctor: PASS,
  rejected by version.

## Evidence

`doc/llzk/evidence/S01/tools.txt` and `substituter-diagnosis.md`.

## Handoff

- Changes made: `PINS.md` records the store path, the acquisition command, the
  versions, and the cache-key requirement. `scripts/llzk/lib.sh` gained
  `require_llzk_sibling`.
- Decisions made: none.
- Deviations: S01 ran after S03–S07 rather than before, because its blocker was
  outside a session's authority.
- Blockers: none remaining.
- What went wrong and what it cost: `/etc/nix/nix.conf` carried the *wrong*
  Ed25519 public key for `veridise-public.cachix.org`, not a missing one. Nix
  selected it by name, failed verification, discarded every substitute, and fell
  back to building LLVM from source without explaining why — and `nix build
  --dry-run` reported the paths as fetchable, because it checks availability,
  not acceptance. Two lasting mitigations: `--max-jobs 0` in the documented
  command, so a substitution failure is an error rather than a silent multi-hour
  build; and the version check in `lib.sh`, so a stale tool cannot pass for a
  pinned one.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: S02 is complete in the same commit; the next real work is
  S08 (proof baseline) or S09+ (constructor expansion).
