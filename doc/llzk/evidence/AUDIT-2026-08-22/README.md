# 2026-08-22 frontend audit evidence

Reviewed starting tree:

- frontend starting HEAD: `13729783d9b7df162fcde86caa17ab0294f078ce`
- Clean base/upstream head: `0e53b9f2d05f06defa2aa0a859f549b611583f10`
- accepted LLZK: `25fb3740ea3465c9129a06289297bb4f0554b7a5`
- checked LLZK main: `b5c110d1088e93d6786f66ec1e155be87bae755f`
- accepted tool output: `/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0`
- LLZK-main tool output: `/nix/store/hvvbkw0afshj37zpiilw0jwxjxfad4p4-llzk-release-3.0.0`

The reviewed repairs are frozen in three commits:

- `350c6348176a0c247918674264698e62e28606b6` — renderer, exact module
  readback, theorem-surface cleanup, and red controls;
- `02a6ecbf518aefa4d829a01bf76ea1632882be38` — public-output execution and
  harness discrimination;
- `7c567f5451c2e40b7be88e96d8a519a7bf82495e` — audit documents and evidence.

The complete clean-tree matrix below was reproduced at `7c567f54` after those
commits were created.

## Complete gate runs

Both the accepted LLZK output and the LLZK-main output ran the same command,
with only `LLZK_OPT`/`LLZK_WITGEN` changed to select the immutable Nix output:

```bash
LLZK_SESSION=codex-release-audit \
LLZK_OPT=/nix/store/.../bin/llzk-opt \
LLZK_WITGEN=/nix/store/.../bin/llzk-witgen \
bash scripts/llzk/e2e.sh
```

Both completed:

```text
PASS: G0 G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12
  15 circuit(s), 51 input vector(s), both witgen backends.
  2 renderer fixture(s), syntax only.
  G10a: all 15 + 2 module(s) admitted by --llzk-product-program.
  G10b: 10 module(s) lowered to SMT, 7 out of scope for a declared reason.
```

Every vector was compared in both `full-witness` and `public` output scopes.
G11 exercised 54 error paths and the action check accepted 15 immutable action
references. The full Lean build completed 1,876 jobs and `CleanTests` completed
1,810 jobs. Its ten warnings are inherited `sorry`s in
`Clean/Utils/Test/TestCircuitProofStart.lean`.

## Theorem probe

Run:

```bash
lake env lean doc/llzk/evidence/AUDIT-2026-08-22/probe.lean
```

The captured output is `axioms.txt`. Generic frontend results contain no
`sorryAx` or native-decision axiom. The concrete examples contain only the
previously documented prime and bit-vector decision facts named in that file.
