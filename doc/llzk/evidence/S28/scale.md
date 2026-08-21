# S28 65536×3 scale evidence

Date: 2026-08-22

Accepted LLZK source: `25fb3740ea3465c9129a06289297bb4f0554b7a5`

Pinned tools:
`/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0/bin`

Measurements use `/usr/bin/time` on the S28 implementation worktree. Times are
wall-clock seconds and memory is maximum resident set size in KiB. They are
engineering scale evidence for this machine, not portable performance bounds.

| operation | elapsed | max RSS |
|---|---:|---:|
| construct and inspect `byteXorRows` through `lean --run` | 1.86 s | 2,189,496 KiB |
| elaborate `TableCert.lean`, including `byteXorTable_certifies` | 1.72 s | 2,202,324 KiB |
| construct, verify, and render the complete 15-artifact corpus | 2.99 s | 2,692,328 KiB |
| pinned `llzk-opt` parse/verify of `And8.llzk` | 0.40 s | 39,196 KiB |
| pinned `llzk-opt --verify-roundtrip` | 0.25 s | 45,804 KiB |
| pinned full-inlining/product-program pipeline | 0.14 s | 42,940 KiB |
| pinned witgen interpreter, vector `[255,255]` | 0.33 s | 38,896 KiB |
| pinned witgen execution engine, same vector | 0.62 s | 65,548 KiB |

The constructed registry reported exactly:

```text
rows=65536
values=196608
first=some #[0, 0, 0]
last=some #[255, 255, 0]
```

`And8.llzk` is 900,610 bytes and 39 lines. Its global begins:

```text
global.def const @ByteXor : !array.type<65536,3 x !felt.type<"babybear">> = [0, 0, 0, 0, 1, 1, ...]
```

All successful stages exited zero. One initial measurement invocation passed
the unsupported `-o` option to `llzk-witgen`; that command exited one before
execution and is excluded from the table. The corrected invocations redirect
stdout and are the two witgen rows above.

Conclusion: the representation is large in Lean memory (about 2.7 GiB at full
corpus emission) but completes quickly and remains small for the pinned LLZK
tools. S28 accepts it as viable while recording the peak rather than hiding it.
