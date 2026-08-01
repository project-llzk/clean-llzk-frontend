# Clean → LLZK current state

Updated: 2026-08-01  
Active milestone: P1 — Lean skeleton and assertion-only circuit (Lean side done,
tool side unverified)  
Last accepted session: S04 — analysis, layout, and the assertion-only vertical slice  
Integration branch: `clean-to-llzk/integration`  
Integration commit: `c3b9a769dfdcb83a202f39726cdb14207868f748`  
Pinned Clean base: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`

## Accepted pins

- Clean: `1e563b9c27991b3795eb440c1ee0757edb4ce8b1`
- LLZK source: `5db6f8f9baaa40787a1a40625796497445f2da36`
- LLZK tools: **not provisioned** — S01
- project-llzk VeIR: `eae1c27e7842c0503233ec99155c39791bd5f502`
- upstream VeIR: `a4e6194d5810a02d74f0094ff6014cda6db6d617`

## State

- Completed:
  - S00 — control plane, pin checker, doctor, baseline build.
  - S03 — backend-local LLZK IR and deterministic renderer.
  - S04 — analysis, layout, and the assertion-only vertical slice. A real
    `FormalCircuit` compiles to textual LLZK; everything outside the Stage-1
    subset is refused with named diagnostics.
- In progress:
  - none.
- Blocked:
  - **S01 — provisioning the LLZK 3.0 tools.** One command away; see below.

## The one open blocker

`/etc/nix/nix.conf` had the wrong Ed25519 public key for
`veridise-public.cachix.org`, so every prebuilt LLZK path failed verification and
Nix silently fell back to a multi-hour LLVM source build. Full diagnosis and
reproduction: `doc/llzk/evidence/S01/substituter-diagnosis.md`.

The key has been corrected to
`veridise-public.cachix.org-1:FvpZ8GzAj1mmJA5PnO9UgKxC6CQdmPutuIKtEpGmeig=`,
which is both what verifies the signatures and what the Cachix API advertises.
The running `nix-daemon` still holds the old key, because it reads its
configuration once at startup. The remaining step is:

```bash
sudo systemctl restart nix-daemon
```

After that, S01 is:

```bash
nix build --no-link --max-jobs 0 --print-out-paths \
  github:project-llzk/llzk-lib/5db6f8f9baaa40787a1a40625796497445f2da36#llzk
```

`--max-jobs 0` is deliberate: it makes a substitution failure an error instead of
a silent multi-hour source build. Expect ~363 MiB of fetches and no compilation.

## Last green gates

Evidence: `doc/llzk/evidence/S00/`, `S03/`, `S04/`.

- G0: `bash scripts/llzk/check-pins.sh` — PASS.
- G1: lint + `lake build --wfail Clean` (1818 jobs) + `lake build CleanTests`
  (1716 jobs) — PASS.
- G2: `Clean/Backend/LLZK/Test/Print.lean` and `Test/Circuit.lean` goldens — PASS.
- G8: three negative fixtures pin exact diagnostics — PASS.

## Not proved yet

**G3, G4, G5, G6, G7 have never run.** No LLZK tool has seen the backend's
output. Its syntax was read from test fixtures in the pinned LLZK revision, not
confirmed by the pinned binaries. Treat the two goldens as *proposals* about
LLZK syntax until S02 validates them.

## Known constraints

- The frontend is a pure Lean backend in Clean which emits textual LLZK.
- VeIR is an independent consumer/proof track, not an initial dependency.
- Stage 1 accepts only the fail-closed subset in `ROADMAP.md`.
- Heavy Nix and Lean builds must not run concurrently on this machine; doing so
  produced a spurious Lean target failure during S00.

## Next session

- Packet: `doc/llzk/sessions/S01-llzk-tooling.md`, then S02.
- Objective: provision the pinned tools, then validate the two existing goldens
  with `llzk-opt` **before** writing any new fixture — the emitter's output is
  now the more useful subject than a handwritten one.
- First command: `sudo systemctl restart nix-daemon`
