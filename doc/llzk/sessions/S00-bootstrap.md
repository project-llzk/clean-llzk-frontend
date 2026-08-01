# S00 — Bootstrap the control plane

Status: accepted  
Depends on: architecture investigation  
Base Clean commit: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Objective

Make the Clean fork the durable, independently resumable project home.

## Deliverables

- Correct `origin` and `upstream` remotes.
- Repository-owned current state, pins, decisions, gates, and roadmap.
- Session packet template.
- Pin checker and doctor script.
- Baseline Lean build evidence.

## Non-goals

- Provisioning LLZK 3.0 tools.
- Writing the handwritten golden LLZK fixture.
- Implementing frontend Lean modules.

## Acceptance gates

- G0: `bash scripts/llzk/check-pins.sh`
- G1: `lake build Clean`
- Repository status is clean after the accepted commit.

## Evidence

`doc/llzk/evidence/S00/`

- `environment.txt` — worktree, branch, HEAD, toolchain, tool versions.
- `gates.txt` — G0 and G1 commands, output, and exit status.

## Handoff

- Changes made: added `doc/llzk/` (current state, pins, roadmap, gates, decisions,
  session template, S00/S01 packets, imported architecture and orchestration
  baselines with provenance) and `scripts/llzk/` (`check-pins.sh`, `doctor.sh`).
- Decisions made: D001–D004.
- Deviations: the orchestration plan describes S00 as creating the worktree and
  branch; both already existed at the pinned base when the session ran, so S00
  verified them instead of creating them. The imported baselines were renamed to
  `doc/llzk/ARCHITECTURE.md` and `doc/llzk/ORCHESTRATION.md` and their origin
  recorded in `PROVENANCE.md`.
- Blockers: none. S01's blocker — no LLZK 3.0 tools — is unchanged and is S01's
  objective.
- Resulting commit: recorded in `doc/llzk/CURRENT.md`.
- Exact next action: run S01 from `doc/llzk/sessions/S01-llzk-tooling.md`; first
  command `bash scripts/llzk/doctor.sh`.

## Observations handed to S01

Found while running S00's gates, and recorded here because they materially
narrow S01:

- The pinned LLZK revision `5db6f8f9baaa40787a1a40625796497445f2da36` was not
  present in the local `llzk-lib` clone until fetched; it is newer than that
  clone's checked-out `HEAD`.
- `/etc/nix/nix.conf` already lists `veridise-public.cachix.org` under
  `extra-substituters` **with** the matching `extra-trusted-public-keys` entry.
  The "unsigned substitute" rejection recorded in the architecture baseline
  (§4.2) does not reproduce: `nix build --dry-run
  github:project-llzk/llzk-lib/5db6f8f9…#llzk` resolves entirely to fetches of
  prebuilt paths (363.5 MiB, including `llzk-release-3.0.0`) with nothing to
  build from source. S01 therefore needs neither an LLVM/MLIR source build nor a
  machine trust change.
- A full `lake build Clean` run concurrently with that Nix download produced one
  spurious target failure. Run heavy Nix and Lean work sequentially.
