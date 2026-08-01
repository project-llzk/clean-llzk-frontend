# Clean → LLZK current state

Updated: 2026-08-01  
Active milestone: P0 — tool and contract spike  
Last accepted session: S00 — bootstrap the control plane  
Integration branch: `clean-to-llzk/integration`  
Integration commit: `a70739408adbdadce38a39affc4fed537efd1ee2`  
Pinned Clean base: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`

## Accepted pins

- Clean: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`
- LLZK source: `5db6f8f9baaa40787a1a40625796497445f2da36`
- LLZK tools: not yet provisioned; S01
- project-llzk VeIR: `eae1c27e7842c0503233ec99155c39791bd5f502`
- upstream VeIR: `a4e6194d5810a02d74f0094ff6014cda6db6d617`

## State

- Completed:
  - S00 — repository-owned control plane, pin checker, doctor, baseline build.
- In progress:
  - none.
- Blocked:
  - none. Current LLZK 3.0 binaries are still unprovisioned; that is S01's
    objective, not a blocker on S01 itself.

## Last green gates

Evidence: `doc/llzk/evidence/S00/`.

- G0: `bash scripts/llzk/check-pins.sh` — PASS.
- G1: `lake build Clean` — PASS, 1811 jobs.

## Known constraints

- The frontend is a pure Lean backend in Clean which emits textual LLZK.
- VeIR is an independent consumer/proof track, not an initial dependency.
- Stage 1 accepts only a fail-closed subset described in `ROADMAP.md`.
- The installed LLZK 2.0 tools do not satisfy the LLZK 3.0 gate.
- Heavy Nix and Lean builds must not run concurrently on this machine; doing so
  produced a spurious Lean target failure during S00.

## Next session

- Packet: `doc/llzk/sessions/S01-llzk-tooling.md`
- Objective: provision and pin current LLZK 3.0 `llzk-opt` and `llzk-witgen`.
- First command: `bash scripts/llzk/doctor.sh`
