# R8 formal frozen-tree review

Review target: exact code candidate
`193ec342cb2aae9055c36f4f77d2a4fe23da7823` in fresh detached worktree
`/tmp/clean-llzk-r8-193ec342-lanef`. The worktree was clean before and after
review. Reviewers were read-only and did not edit the candidate. The blind
findings were written during the preceding frozen-candidate pass before
`doc/llzk/review/CONTROL-SET.md` was opened. The `193ec342` restart necessarily
retained that knowledge: each lane re-audited the exact candidate and its
two-file delta, then audited S1–S6 explicitly. This record does not call the
final exact-candidate pass blind.

The first formal pass on parent candidate `4819f6ed` was deliberately not
grandfathered. Lane C found the live stale/vacuous Plonky3 public command, and
Lane B rejected `/tmp`-only matrix/reproduction evidence. Those findings created
new candidate `193ec342`, caused affected tests/matrices to rerun, and restarted
the affected lanes.

## Lane A — theorem, output carrier, lookups, and corpus: GO

The independent theorem/output reviewer found no candidate blocker.
`193ec342` changes no Lean file from already reviewed `4819f6ed`: the entire
`Clean` and `Clean/Backend/LLZK` trees are byte-identical.

The review followed public values from exact `w0…` then `out0…` member layout,
through every output write/read and G9 equality, to
`moduleOutput = fromElements (Vector.mapRange (size Output) outs)`. Both generic
soundness forms and all eight Add8, And8, Xor32, and BLAKE3.G primary/source-row
wrappers conclude `Spec` for that ordered typed module output while retaining
compile/readback/recognition, equality, lookup, input-evaluation, and normalized
assumption premises. Circuit-specific lookup proofs resolve Xor32 and BLAKE3.G
to exact certified table carriers; same-name/same-arity fake tables cannot
satisfy those resolvers. Dropped, duplicated, reordered, substituted, and
first/middle/last row attacks remain red.

The reviewer also rechecked CopyCanon preservation and non-copy controls,
Xor32 operation/divisor/operand/output attacks, BLAKE3.G's exact 72/96/64
interface and public layout, every fixed public-oracle output, swapped source
arguments, and the `2^32` range boundary. The focused 1776-job soundness build
and current R8 probe pass; no printed closure contains `sorryAx`.
`moduleOutput_eq_of_compile` uses only `propext`, `Classical.choice`, and
`Quot.sound`.

Historical `evidence/S29/blake3g-probe.lean` is exact evidence for old commit
`a3299ca0` and intentionally states the old internal-Clean-output conclusion; it
is not a current-tree pass claim. Current `module-output-probe.lean` is the
Phase-C replay for the repaired API, with four explicit typed applications and
all eight wrapper axiom probes. Historical files and hashes were not rewritten.

## Lane B — gates, matrices, provenance, and evidence: GO

The independent gate/evidence reviewer mechanically audited both raw 557-line
matrix transcripts and independently reproduced their hashes, tool identities,
candidate attribution, reachability counts, G11 187 controls, exact 17/67/2
corpus, G9 11+6 split, 19 product calls, 10/9 SMT split, both witness modes and
both output scopes, terminal banners, and absence of unexpected failure tokens.
The raw cross-log diff contains only two exact store paths and one Lean
replay-progress line; the complete recorded normalization makes the streams
byte-identical.

The reviewer traced exact G4 and G10a calls through the three optimizer probes,
all 17 corpus paths, and both fixtures. The vulnerable-parent transcript proves
real-reject/wrapper-accept/helper-green before repair and helper-red after repair
for flag-selective, roundtrip-strip, product-no-output, and
marker-fabricating/root-permissive attacks. Wrapper and input contents are
tracked. The Plonky3 count/name/list/target/`--include-ignored` design was also
reviewed against its exact 1/2/2/2 registered sources and sealed replay.

The lane's initial NO-GO was evidence durability, not implementation behavior.
That finding is closed by `FINAL-VERIFICATION.md`, the two raw matrix logs,
complete G4/G10a transcript and inputs, exact Plonky3 command/output, theorem
output, commands, exit statuses, hashes, counts, and this attributed formal
record. The evidence/status commit is explicitly a docs-only child; it is not
misrepresented as the matrix-tested candidate.

## Lane C — public path, governance, lock, and publication: GO

The independent public/governance reviewer found exactly five documents on the
root onboarding path and five on the frontend reading path, with historical
review/session/evidence material explicitly separated. A repo-wide scan of
tracked Markdown local targets found no missing target after the Plonky3 repair;
no stale `clean_air.rs`, `test_clean_fib`, or placeholder `example.com` remains.

PINS, CONTRIBUTING, CONCURRENCY, GATES, D037, and the lock implementation agree:
compatible `flock` is required; the persistent guard serializes short owner-file
transactions; the long-lived owner remains advisory; owner updates are atomic;
release requires exact identity; direct deletion is not recovery. Owner and
guard bytes, inodes, sizes, and mtimes remained unchanged through candidate
validation. CI action SHAs, Ubuntu/Rust/Nix inputs, read-only permissions,
security guidance, and the four required jobs remain explicit.

The Plonky3 README now links the real integration test and uses the same
non-vacuous registration/run structure as CI. The exact candidate replay passed
all 1/2/2/2 tests with none failed, ignored, or filtered. Active documents name
`193ec342` as the locally tested code candidate and the later closure as evidence
only. They do not claim a push, organization CI, repository creation/transfer,
private-reporting activation, settings change, or publication authorization.

## Post-blind S1–S6 controls

- S1 is closed by construction: the root component is fixed to literal `Main`;
  there is no caller-supplied component symbol.
- S2 is closed by the table/`Main` collision diagnostic and its red fixture.
- S3 is closed: both `Demo` and `Empty` renderer fixtures reach G3, G4, and G10.
- S4 is partially closed and honestly bounded: empty member/parameter,
  zero-witness, zero-output, and no-constraint shapes are covered; a true
  zero-input source circuit remains a recorded Stage-2 limitation because the
  current source construction requires positive input size.
- S5 is closed by `Passthrough` and `ConstOut` corpus entries.
- S6 is closed: neither `Ty` nor `Value` derives `Inhabited`.

The controls added no hidden candidate defect. Lane B recorded that its blind
method had not independently surfaced every S1/S2/S6 control and amended its
method to inspect API signatures, namespaces/negative fixtures, default-instance
surface, and an input/member/witness/output cardinality grid.

## Accepted boundaries and final disposition

The generic caller-selected table-identity gap (D012) and absence of formal LLZK
semantics or a constraint executor (D017) remain open and prominent. G10 admits
and lowers modules but runs no solver. `llzk-witgen` checks computation and does
not execute `@constrain`. S4's zero-input remainder is not silently counted as
covered.

Final disposition: all three independent lanes GO on exact code candidate
`193ec342`. This is a local frozen-candidate R8 result, not publication
authorization.
