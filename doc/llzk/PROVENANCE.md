# Provenance of the imported baselines

These two documents were authored in the unversioned coordination directory
`/home/alh/LLZK` before this repository owned the project. S00 imported them
verbatim so that a fresh session can resume from repository files alone.

| Repository file | Imported from | sha256 |
|---|---|---|
| `doc/llzk/ARCHITECTURE.md` | `/home/alh/LLZK/clean-to-llzk-plan-2026-07-31.md` | `5c8dddbccc005899165eb094677cb8e32732d2b724fc5fe32b2074f109abf9f7` |
| `doc/llzk/ORCHESTRATION.md` | `/home/alh/LLZK/clean-to-llzk-session-orchestration.md` | `4bd3bc0c5d1c031f5552597bc050f20047fbf4fa6c970ff06b2ee5c6aba26653` |

Imported: 2026-08-01 by session S00.

`ARCHITECTURE.md` is the accepted design baseline. `ORCHESTRATION.md` is the
accepted execution protocol. Where `ROADMAP.md`, `GATES.md`, or `DECISIONS.md`
add detail, they refine these documents; where they contradict them, the
contradiction is a defect to be resolved by a decision entry.

## Recorded deviations from `ORCHESTRATION.md`

Deviations from the execution protocol, so that the protocol's own gaps are
visible rather than inferred from a missing file.

| Deviation | Recorded by |
|---|---|
| **S06 has no session packet.** The work is real — commit `1c1cf413`, `evidence/S06/gates.txt`, and D012/D013 are attributed to it — but no packet was written before or after it, and no deviation recorded the omission at the time. Not back-dated: a packet written now would be a reconstruction, which is worse than an acknowledged gap. | R2-15, entered by S14 |
| **Sessions did not record their resulting commit.** Every packet through R2 says "Resulting commit: recorded in `doc/llzk/CURRENT.md`", which records only the latest integration commit, so nothing links a packet to the commit it produced. From S08 on, each packet's Handoff records its own commit. | R2-15 / F2, entered by S14 |
| **R0 and R1 were never run.** The planned order was `S02 → R0 → S03 → S04 → R1 → …`; S01 stalled and the increments were brought forward. R2 ran against the accumulated surface instead. R0 and R1 are now moot rather than outstanding, and `ROADMAP.md` says so. | S14 |
