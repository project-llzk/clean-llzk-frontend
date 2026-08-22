<p align="center"> <img src="images/logo-w-subtitle-rect.png" width="400" alt="Clean logo"> </p>

<div align="center">

[![Chat on Telegram][ico-telegram]][link-telegram]
[![Ask DeepWiki][ico-deep-wiki]][link-deep-wiki]

</div>

# Clean to LLZK frontend

This fork develops a **fail-closed, assurance-oriented LLZK frontend for
Clean**. Clean circuits are written and proved in Lean; the frontend analyzes a
documented subset, lowers it through a small typed IR, emits textual LLZK, and
checks the result with the pinned LLZK toolchain.

Stage 1 is complete. Its reference example, Clean's formally proved
`Addition8FullCarry` gadget, is compiled to LLZK, parsed, verified,
round-tripped, and run through both LLZK witness generators. The composed
`BLAKE3.G 0 1 2 3` and `Xor32` headlines now follow the same external path with
fixed independently derived public outputs. The emitted constraints and witness
program are also compared in Lean with the circuit they came from. The
[generated example showcase](doc/llzk/EXAMPLES.md) derives the current module
and vector counts from the tested corpus and explains exactly what each example
establishes.

The project is deliberately explicit about its boundary: this is a
translation-validating source-to-typed-module pipeline with proved component
lemmas and differential checks over the rendered artifact; it is not a verified
translator or a formal semantics of LLZK text. Open assurance gaps are kept in
one [gap register](doc/llzk/GAPS.md), rather than hidden behind a general
"verified" label.

Start here:

- [Verified example showcase](doc/llzk/EXAMPLES.md)
- [Frontend guide and document map](doc/llzk/README.md)
- [Current status and exact next action](doc/llzk/CURRENT.md)
- [Capability roadmap](doc/llzk/ROADMAP.md)
- [Assurance gaps and claim boundary](doc/llzk/GAPS.md)
- [Latest complete frontend audit](doc/llzk/review/FRONTEND-AUDIT-2026-08-22.md)

Project governance:

- [Public-readiness milestone](doc/llzk/PUBLIC-READINESS.md)
- [Prepared organization settings](doc/llzk/PUBLICATION.md)
- [Contribution guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

To build the Lean project:

```bash
lake build
lake build CleanTests
```

The full LLZK conformance run needs the pinned tools described in
[`doc/llzk/PINS.md`](doc/llzk/PINS.md):

```bash
export LLZK_SESSION=my-session
export LLZK_OPT=/path/to/llzk-opt
export LLZK_WITGEN=/path/to/llzk-witgen
bash scripts/llzk/worktree-lock.sh claim "full LLZK conformance run"
bash scripts/llzk/e2e.sh
```

The latest recorded run passed 17 corpus modules and 67 vectors through both
LLZK witness backends in both full-witness and public-output scopes, with all
19 emitted corpus-plus-fixture modules admitted to the product-program
pipeline. Exact commit, tool, proof, and gate evidence is linked from
[`doc/llzk/CURRENT.md`](doc/llzk/CURRENT.md).

## About Clean

`clean` is an embedded Lean DSL for writing zk circuits, targeting popular arithmetizations like AIR, PLONK and R1CS.

**Check out our blog post for an introduction: https://blog.zksecurity.xyz/posts/clean**

`clean` is developed by [zkSecurity](https://zksecurity.xyz/), currently as part of a Verified-zkEVM grant.

We intend to build out `clean` into a universal zk framework that produces **formally verified, bug-free circuits** for the entire ecosystem. See the [roadmap](#roadmap).

## Community

Public Telegram group to discuss `clean`: [t.me/clean_zk](https://t.me/clean_zk)

Please join if you want to use `clean`, or contribute, or if you have any questions!

We always welcome contributors! Check out our [good first issues](https://github.com/Verified-zkEVM/clean/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22good%20first%20issue%22).

## Using the repo

Follow [official instructions](https://lean-lang.org/lean4/doc/setup.html) to install `elan` (the package manager) and Lean4.

Clone this repo, and test that everything works by building:

```bash
lake build
```

After that, we recommend open the repo in VSCode to get immediate inline feedback from the compiler while writing theorems.

Make sure to install the `lean4` extension for VSCode!

## Documentation

We are actively working on creating proper documentation for `clean`. In the meantime, we recommend checking out our [AI-generated DeepWiki](https://deepwiki.com/Verified-zkEVM/clean).

⚠️ **Disclaimer:** The wiki may contain inaccuracies or outdated details. Please take all information with a grain of salt until the official documentation is released.

## Code Style

We follow standard Lean/Mathlib conventions with some local variations. See [doc/conventions.md](doc/conventions.md) for details.

## Proof Finding Guide

Some heuristics for finding proofs are in [doc/proving-guide.md](doc/proving-guide.md).

## Roadmap

The following is a rough, longer-term roadmap for clean. Note that some of the bullets below could be multi-month projects!

Reach out [on TG](https://t.me/clean_zk) if you are looking for long-term contribution opportunities and you are interested in any of these!

- ✅ More general lookups + VM-like table ensembles
  - main refactor merged as https://github.com/Verified-zkEVM/clean/pull/328
  - subproject (TODO): support in plonky3 backend
- Polish plonky3 backend, generate constraint evaluation Rust code
  - currently worked on by [zkSecurity](https://zksecurity.xyz/) https://github.com/Verified-zkEVM/clean/pull/192
- clean documentation
  - will be worked on by [zkSecurity](https://zksecurity.xyz/)
- ✅ Witness generation: compile (subset of) Lean to IR, to generate fast WG code in backends
  - solved by moving to a witness generation IR https://github.com/Verified-zkEVM/clean/pull/403
- Create clean circuits from LLZK
  - this gives us frontends like Circom
  - subproject: demonstrate actual e2e extraction from Circom
- Verifier challenges https://github.com/Verified-zkEVM/clean/issues/162
  - prove lookup protocols end to end
  - should be optional, should be able to abstract
- Explore if we can compose with ArkLib to get e2e verification
- More backends
  - stwo?
  - some R1CS
- Support PLONK circuits with custom gates
- Good AGENTS.md / CLAUDE.md
- AIR table foundation, more low-level, no monad
  - different entry points for different kinds of tables
- Support Binius
- Proof automation:
  - `circuit_proof_start` should handle vectors and general ProvableTypes
  - `circuit_proof_start` could detect subcircuits to unfold (in the right places)
  - better automation for `localLength_eq`, `subcircuitsConsistent` etc
- Advanced: Mixed proof systems like Longfellow-ZK
- MORE GADGETS
- MORE INTEGRATIONS
-

## Attribution

The Lean name and logo are trademarks of Lean FRO.

[ico-telegram]: https://img.shields.io/badge/@clean__zk-2CA5E0.svg?style=flat-square&logo=telegram&label=Telegram
[link-telegram]: https://t.me/clean_zk
[ico-deep-wiki]: https://deepwiki.com/badge.svg
[link-deep-wiki]: https://deepwiki.com/Verified-zkEVM/clean
