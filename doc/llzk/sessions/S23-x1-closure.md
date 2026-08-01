# S23 — Close R5's X1 instead of confining it

Status: proposed  
Depends on: S22 (X1 confined), and on the worktree being free  
Worktree: `/home/alh/LLZK/clean-llzk-frontend`  
Branch: `clean-to-llzk/integration`

## Why this packet exists rather than the change

S22 confined X1: `Config`'s constructor is private, tables enter through
`Config.unsafeWithTables`, and G12 keeps that name out of non-test modules.

That is not closure. `Config.ofCertified` takes `CertifiedTable`s and then
**erases their proofs** — it returns a plain `Config`, so by the time `compile`
runs, the certificate is gone and the compiler is trusting a convention plus a
grep. A caller inside `Test/` can still emit a weakened module, and so could any
future non-test caller that G12's allow-list is widened for.

The change below removes the erasure. It was not made in S22 because the
worktree was being edited concurrently by a session working R5's X3/X3b in
`Analyze.lean`, `Circuit.lean`, `Constraints.lean` and `Witness.lean` — exactly
the files this touches. Starting it would have been the fourth collision in a
day. See S22's Attribution section.

## Objective

Make it impossible to reach the supported compile entry points with uncertified
tables, so the certificate is a precondition of emission rather than a
convention around it.

## The change

Carry the proofs to the entry point instead of erasing them at the wrapper.

```lean
/-- A configuration whose tables carry their certificates. -/
structure CertifiedConfig (F : Type) [FiniteField F] where
  field : FieldSpec
  tables : Array (CertifiedTable F)

/-- The `Config` the compiler already understands. Total: certificates only
constrain the rows, never their shape. -/
def CertifiedConfig.toConfig (c : CertifiedConfig F) : Config :=
  Config.unsafeWithTables c.field (c.tables.map (·.exported))
```

Then re-sign the public surface in `WitnessCheck.lean` — these six, which are
the only public entries that take a `Config`:

| Entry | New first argument |
|---|---|
| `compile` | `CertifiedConfig F` |
| `emit` | `CertifiedConfig F` |
| `emitSource` | `CertifiedConfig F` |
| `compileSourceVerified` | `CertifiedConfig F` |
| `witnessAgree_of_compileSourceVerified` | `{cfg : CertifiedConfig F}` |
| `constraintsAgree_of_compileSourceVerified` | `{cfg : CertifiedConfig F}` |

Each body starts by projecting `cfg.toConfig`, so nothing below changes and the
two theorems keep their current proofs modulo that unfolding.

`Config` itself stays public and `unsafeWithTables` stays, because the negative
fixtures need malformed registries and `Analyze`/`Circuit`/`Constraints` need a
plain `Config` internally. What changes is that nothing *public* accepts one.

## Call sites to update

Read off the tree at `07c8cd77`:

- `Corpus.lean:63` — `compileSourceVerified cfg src`. `Entry.cfg` becomes a
  `CertifiedConfig`. `Examples.withBytes` is already
  `Config.ofCertified .babybear #[⟨byteTable, Gadgets.ByteTable, byteTable_certified⟩]`,
  so it becomes the `CertifiedConfig` literal directly and `ofCertified` is
  retired.
- `Examples.babybear` and the several table-free configs become
  `CertifiedConfig` with `tables := #[]`.
- `Test/Circuit.lean` — eight `emitSource babybear …` negative fixtures, plus
  the malformed-registry fixtures. The malformed ones must keep reaching a
  `Config`, so they move to a lower-level entry (`compileSource`, already
  public) and G12's allow-list is unchanged.

## Non-goals

- **Tying an `ExportTable` to the `Table` a `RawTable` erased.** That is D012
  and stays impossible for the compiler; the certificate is a human proof. This
  packet only stops the proof being discarded before it reaches the compiler.
- `Gadgets.ByteTable`'s certificate stays the hand-proved `byteTable_certifies`,
  because it inlines its `StaticTable`. D012's follow-up is still open and is
  not this packet.

## Acceptance gates

- G0–G12 green.
- A new negative control, alongside S22's `fatBytes` guards: the `fatBytes`
  configuration **cannot be given to `compile`** — the type demands a
  `CertifiedTable` and `ExportTable.Certifies` is false for it, so there is no
  term to supply. State this as a comment naming the missing proof, not as a
  `#guard`, since it is a compile-time absence rather than a runtime fact.
- G12 still green and still falsifiable.

## What to claim afterwards, and what not to

Afterwards it is true that *the supported entry points cannot emit a module with
uncertified tables*. It is **not** true that emitted lookup constraints are
sound in general — that still rests on the certificate being proved for the
table in question, and on D017's reading of `constrain.in` as membership.

Write the weaker claim. R5 exists because this project has repeatedly written
the stronger one.
