# S28 — Multi-column lookup tables: retire D013

Status: outline (bootstrapped by R7; expand to a full packet after S26 lands)
Depends on: S26 (the bitwise witness-IR increment) — the two together are what
unlock the bitwise gadgets; neither alone does.
Worktree: `/home/alh/LLZK/clean-llzk-frontend`

## Why this session exists

R7-05: the ROADMAP used to claim the bitwise half of Clean's gadget library was
blocked by "exactly two witness-IR constructors". Its own diagnostic counts
refuted that — 80–89% of the refusals behind that claim are lookups into
`ByteXorTable` and its siblings: **3-column, 65536-row tables**, which D013
refuses (single-column only). `Test/Coverage.lean` pins the decomposition:
`Keccak256.Theta` is 50 × `lxor` + **400 × table refusals**. So after S26, every
one of Xor32/And8/Or8/Keccak/BLAKE3 still refuses, for the table reason alone.

## What it takes (from D013, which recorded the shape of the work)

- **Emitter IR**: `array.new` for multi-column rows, and a multi-dimensional
  `constrain.in` — confirm the exact LLZK 3.0 syntax against the pinned
  `llzk-opt` before designing, as S26's dialect note says; renderer fixtures for
  both (G2/G3), so the syntax is validated before any circuit uses it.
- **Registry**: `ExportTable` already carries `arity` and rows as
  `Array (Array Nat)`; `ExportTable.diagnose` and `recognizeLookup` drop their
  arity-1 refusals in favour of arity-consistency checks; the D012 obligation
  (`Certifies`) restates over rows rather than values — its canonicity bound and
  `certified_membership` need multi-column counterparts, and A1's chain
  (`registryOk_of_recognize` → `canonical_of_recognize`) must be re-proved at
  the new type, not weakened.
- **Certification at scale, measured**: `ByteXorTable` is 65536×3 = 196,608
  values. `byteTable_certifies` is a 256-row `rfl`-adjacent proof; nobody has
  measured what the same discipline costs at 65536 rows, in `#guard` time (it
  gates G1) or in proof elaboration. If it does not scale, that is a finding to
  record, not a reason to weaken the certificate — a `fromStatic`-generic
  certification theorem (the `ofStatic_certifies` shape) may carry it.
- **Corpus**: `Xor32` and `And8` as corpus entries with input vectors — the
  point of the session is that these go through `llzk-opt` and both witgen
  backends, not just `compile`. Then `BLAKE3.G`/`Keccak256.Theta` as compile
  verdicts flipping in `Test/Coverage.lean`.
- **G8**: negative fixtures for every refusal that moves (arity mismatches
  change meaning), per the usual increment shape (D009).

## Acceptance sketch

- `Test/Coverage.lean`: the four bitwise rows' refusal counts drop to zero (or
  to exactly their residual non-table reasons), as edited `#guard`s.
- All gates green with the corpus grown; `e2e.sh` counts updated.
- GAPS §1 wording re-checked: the certificate story now covers a table five
  hundred times larger than the one it was written for.
