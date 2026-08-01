# Clean → LLZK current state

Updated: 2026-08-01  
Active milestone: P2 complete on the Lean side; **no LLZK tool has run**  
Last accepted session: S07 — emitter command and conformance harness  
Integration branch: `clean-to-llzk/integration`  
Integration commit: `1f560aa19181e276acc67290b03bffa387cf5972`  
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
  - S04 — analysis, layout, and the assertion-only vertical slice.
  - S05 — the two justified natural division/modulo witness shapes.
  - S06 — table export registry, lookups, and `Gadgets.Addition8FullCarry`.
  - S07 — the emitter command and the fail-closed conformance harness.

  The whole Stage-1 emitter exists and is golden-tested. `Addition8FullCarry`
  compiles end to end.
- In progress:
  - none.
- Blocked:
  - **S01 — provisioning the LLZK 3.0 tools.** One command away; see below.
    S02, R0, R1 and R2 all wait on it.

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

Evidence: `doc/llzk/evidence/{S00,S03,S04,S05,S06,S07}/`.

- G0: `bash scripts/llzk/check-pins.sh` — PASS.
- G1: lint + `lake build --wfail Clean` (1820 jobs) + `lake build CleanTests`
  (1718 jobs) — PASS.
- G2: the goldens in `Clean/Backend/LLZK/Test/{Print,Circuit}.lean` — PASS.
  They pin the renderer over every IR constructor, and the full emitted module
  for `Multiply`, `Decompose` and `Addition8FullCarry`.
- G8: eight negative fixtures pin exact diagnostics — PASS. `scripts/llzk/e2e.sh`
  and `doctor.sh` verified to reject a missing tool and the installed LLZK 2.0
  binary.

## Not proved yet — read this before trusting the output

**G3, G4, G5, G6, G7 have never run.** No LLZK tool has seen the backend's
output. Its syntax was read from test fixtures in the pinned LLZK revision, not
confirmed by the pinned binaries. Treat every golden as a *proposal* about LLZK
syntax until `e2e.sh` runs.

G5/G6/G7 are also not implemented: they need a per-circuit input corpus and a
Clean-side witness comparison. `e2e.sh` says so rather than passing silently.

Two semantic arguments in the backend are prose, not proof, and are exactly what
G5/G6 would test:

- D011 — that `felt.umod`/`felt.uintdiv` on canonical representatives agree with
  Clean's `ofNat (mod (val x) c)`.
- D012 — that the rows in `Config.tables` are the table's rows. The backend
  cannot check this; `ExportTable.ofStatic` is the mitigation where a
  `StaticTable` is in scope, and `Gadgets.ByteTable` is not such a case.

## Known constraints

- The frontend is a pure Lean backend in Clean which emits textual LLZK.
- VeIR is an independent consumer/proof track, not an initial dependency.
- Stage 1 accepts only the fail-closed subset in `ROADMAP.md`.
- Heavy Nix and Lean builds must not run concurrently on this machine; doing so
  produced a spurious Lean target failure during S00.

## Next session

- Packet: `doc/llzk/sessions/S01-llzk-tooling.md`, then S02.
- Objective: provision the pinned tools, then run the harness against the
  emitted corpus. Do **not** write a fresh handwritten fixture first: the
  emitter's output is now the more useful subject, and S02's job is to find out
  where it is wrong.
- First commands:

```bash
sudo systemctl restart nix-daemon
nix build --no-link --max-jobs 0 --print-out-paths \
  github:project-llzk/llzk-lib/5db6f8f9baaa40787a1a40625796497445f2da36#llzk
export LLZK_OPT=<that path>/bin/llzk-opt
export LLZK_WITGEN=<that path>/bin/llzk-witgen
bash scripts/llzk/e2e.sh
```

Expect that first `e2e.sh` run to fail somewhere in the syntax. That is the
point of it, and the fix belongs in `Print.lean` plus a golden update.
