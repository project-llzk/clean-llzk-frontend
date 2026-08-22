# Clean → LLZK frontend: refreshed architecture and execution plan

**Date:** 2026-07-31  
**Status:** investigation closeout and proposed execution baseline  
**Supersedes:** `clean-to-llzk-plan.md` where this document differs  
**Preserves:** the textual-MLIR decoupling principle from
`clean-to-veir-readiness.md`

## 1. Executive decision

Build the first frontend as a **pure Lean backend in Clean** which emits one
small, explicitly versioned subset of textual LLZK. Validate that text with the
current C++ LLZK 3.0 tools. Do **not** make the first frontend depend directly on
VeIR.

Use VeIR in a second, non-blocking track:

1. immediately, as an additional parse/round-trip consumer where unregistered
   operations/types are sufficient;
2. later, as a registered LLZK verifier and interpreter after its LLZK dialect
   coverage and fork/upstream strategy are resolved;
3. ultimately, as the semantic target for lowering-correctness proofs.

This originally gave the requested Lean implementation without coupling Clean's
Lean 4.30 toolchain to either the project LLZK VeIR fork (4.31-rc2) or upstream
VeIR (4.32.2). S25 moved Clean itself to Lean 4.32.2, so the toolchain mismatch
half of that rationale has lapsed. D003 still rests on the substantive boundary:
the accepted VeIR inputs do not provide the complete Struct, Array,
`constrain.in`, and `function.call` surface this frontend emits.

## 2. Exact source state reviewed

The table below is the 2026-07-31 investigation baseline, not the current pin
register. S25 advanced Clean to
`0e53b9f2d05f06defa2aa0a859f549b611583f10` / Lean 4.32.2 on 2026-08-21;
`PINS.md` is authoritative for accepted inputs.

| Project | Ref reviewed | Toolchain / relevant state |
|---|---|---|
| Clean | `1e563b9c27991b3795eb440c1ee0757edb4ce8b1` | Lean `v4.30.0`; witness IR and JSON export present |
| LLZK | `25fb3740ea3465c9129a06289297bb4f0554b7a5` | Accepted LLZK 3.0 pin; `llzk-witgen` has interpreter and execution-engine backends; current-main compatibility is recorded in the 2026-08-22 audit |
| project-llzk VeIR | `eae1c27e7842c0503233ec99155c39791bd5f502` | Lean `v4.31.0-rc2`; Felt/Bool/Constrain.eq subset, no Struct/Array runtime |
| opencompl VeIR | `a4e6194d5810a02d74f0094ff6014cda6db6d617` | Lean `v4.32.2`; verifier is actively moving to dialect-local `OpInfo` |
| llzk-lean accepted VeIR pin | `d899d95004d4bd988c8456d686c33b11a7a5eb4a` | Clean dependency pin; workspace VeIR is only descendant context |

The strict `llzk-lean` and VeIR doctor checks, pin checks, and companion checks
all pass. The existing harness remains trustworthy for its documented Felt
scope, but it is not frontend or witness-generation acceptance evidence.

## 3. What the previous plan got right

- Clean's `WitgenIR` removes the opaque-closure blocker for the intended first
  gadgets.
- `Addition8FullCarry` is a good first vertical slice.
- A textual LLZK artifact is the right stable seam between independently
  versioned Lean projects and the C++ reference implementation.
- Flattening Clean subcircuits before lowering avoids `function.call` and
  nested component composition in the first stage.
- Clean's AIR/table-ensemble layer and channel interactions should remain out
  of the scalar `FormalCircuit` MVP.
- VeIR Struct, Array, aggregate runtime values, and LLZK interpreter semantics
  are genuinely separate workstreams and must not block the frontend.

## 4. Corrections found in the fresh review

### 4.1 Current LLZK syntax differs from the old contract

The root module needs `llzk.lang`, and an executable main needs
`llzk.main = !struct.type<@Main>`. The field registry attribute is
`llzk.fields`, not `veir.fields`.

Current member operations are `struct.member`, `struct.readm`, and
`struct.writem` (not `field`, `readf`, or `writef`).

The frontend validation command is an ordinary `llzk-opt input.llzk -o
/dev/null` parse/verify, optionally with `--verify-roundtrip`; there is no
frontend-specific `llzk-opt --verify` mode.

### 4.2 `llzk-witgen` is real, but the installed workspace package is stale

Current LLZK 3.0 contains:

- `llzk-witgen <module> --inputs <json>`;
- interpreter and execution-engine backends;
- named arguments through `function.arg_name`;
- public-output and full-witness JSON modes;
- `--check-output`.

The installed LLZK 2.0 Nix output only contains `llzk-opt`,
`llzk-lsp-server`, and `r1cs-opt`. A current LLZK 3.0 tool package must be made
available before executing the golden fixture. The current public Cachix
substitute was offered but rejected as unsigned by the local Nix configuration,
causing a source build of LLVM/MLIR; that build was intentionally stopped.

### 4.3 Clean erases concrete lookup-table rows

`FlatOperation.lookup` contains a `RawTable` with a name, arity, and logical
predicates. A `StaticTable`'s `length` and `row` function are gone after
`Table.toRaw`. Therefore an emitter cannot recover ByteTable's 256 rows by
walking `Operations.toFlat`.

The first backend needs an explicit table registry:

```lean
structure ExportTable (F : Type) where
  name : String
  arity : Nat
  rows : Array (Array F)

structure Config (F : Type) where
  fieldName : String
  tables : Array (ExportTable F)
```

Provide `ExportTable.ofStatic` while a `StaticTable` is still available. The
compiler must fail closed on an unresolved name/arity pair. A later Clean API
change may retain optional export metadata in `RawTable`, but that is not
required for the first slice.

### 4.4 Clean exportability is weaker than LLZK lowerability

`#assert_exportable` rejects only `.native` witness programs. It does not
reject:

- `.interact`;
- unresolved lookup tables;
- `dataGet` or `hintGet`;
- witness-IR constructs outside the selected LLZK subset;
- natural-number computations that exceed the selected machine-index model.

Add a backend-specific analysis:

```lean
def analyze (cfg : Config F) (circuit : FormalCircuit F I O) :
    Array Diagnostic
```

Compilation succeeds only when this diagnostic array is empty.

### 4.5 `NExpr` is not field arithmetic

Clean `NExpr` denotes unbounded `Nat`. It is not generally correct to lower
`add`, `mul`, `div`, `mod`, bit operations, and shifts to `felt.*`, because
field reduction changes intermediate natural values.

The principled general lowering is:

- `NExpr.val` → `cast.toindex`;
- natural constants/arithmetic/comparisons → `arith` on `index`;
- `FExpr.ofNat` → `cast.tofelt`.

LLZK's current witness interpreter models `index` as a signed 64-bit carrier
and does not yet interpret every natural operation needed by `WitgenIR`.
Therefore Stage 1 must:

1. recognize the safe `ofNat (mod (val x) (const c))` and
   `ofNat (div (val x) (const c))` shapes used by Addition8;
2. lower those directly to `felt.umod` and `felt.uintdiv`, subject to an
   explicit proof obligation/analysis that the source `val x` is the intended
   canonical representative and no prior natural arithmetic was lost;
3. reject other `NExpr` forms until the index semantics and bounds policy are
   implemented.

Also note that `BExpr.neq` currently means **Nat equality** (`eval` uses `=` and
the JSON tag is `natEq`); it must lower to equality, not inequality.

### 4.6 Output names and table schemas are not recoverable generically

`ProvableType` preserves flattening and reconstruction, but not user-facing
member names. The MVP should use stable generated names:

- compute arguments: `arg0`, `arg1`, ... with matching
  `function.arg_name`;
- witness members: `w0`, `w1`, ...;
- public outputs: `out0`, `out1`, ... as dedicated `{llzk.pub}` members. Each is
  written by `@compute` and constrained equal to the corresponding Clean output
  expression, so constants, inputs, and compound expressions work uniformly.

A later derivable `LLZKLayout`/schema typeclass can preserve source names.

## 5. Stage-1 LLZK contract

One flattened `FormalCircuit` becomes:

```mlir
module attributes {
  llzk.lang = "clean",
  llzk.main = !struct.type<@Main>,
  llzk.fields = [#felt.field<"babybear", 2013265921>]
} {
  global.def const @Bytes :
    !array.type<256 x !felt.type<"babybear">> = [0, 1, ...]

  struct.def @Main {
    struct.member @w0 : !felt.type<"babybear"> {llzk.pub}
    struct.member @w1 : !felt.type<"babybear"> {llzk.pub}

    function.def @compute(
      %arg0 : !felt.type<"babybear"> {function.arg_name = "arg0"},
      %arg1 : !felt.type<"babybear"> {function.arg_name = "arg1"},
      %arg2 : !felt.type<"babybear"> {function.arg_name = "arg2"}
    ) -> !struct.type<@Main>
      attributes {function.allow_non_native_field_ops} {
      %self = struct.new : !struct.type<@Main>
      // structurally lowered WitgenIR, in operation order
      struct.writem %self[@w0] = %z : !struct.type<@Main>, !felt.type<"babybear">
      struct.writem %self[@w1] = %carry : !struct.type<@Main>, !felt.type<"babybear">
      function.return %self : !struct.type<@Main>
    }

    function.def @constrain(
      %self : !struct.type<@Main>,
      %arg0 : !felt.type<"babybear">,
      %arg1 : !felt.type<"babybear">,
      %arg2 : !felt.type<"babybear">
    ) {
      // read witness cells
      // lower asserts to felt expression + constrain.eq with zero
      // lower lookup after global.read @Bytes
      function.return
    }
  }
}
```

Stage-1 accepted Clean inputs:

- prime-field `FormalCircuit`s;
- inputs, outputs, and local witnesses flattened to field cells;
- structured `.ir` witness programs only;
- `Expression`: var, const, add, mul;
- the two recognized Addition8 natural div/mod forms;
- `.assert`;
- `.lookup` only when resolved by `Config.tables`;
- no `.interact`, `.native`, `dataGet`, or `hintGet`.

## 6. Implementation shape inside Clean

Recommended directory:

```text
Clean/Backend/LLZK/
  Basic.lean          -- Config, diagnostics, public compile API
  IR.lean             -- deliberately small typed emitter IR and SSA builder
  Analyze.lean        -- fail-closed capability and table checks
  Expression.lean     -- Clean Expression lowering
  Witness.lean        -- WitgenIR subset lowering
  Circuit.lean        -- module/struct/compute/constrain construction
  Print.lean          -- deterministic LLZK renderer
  Command.lean        -- #emit_llzk / file-output command
  Test/
```

Do not concatenate arbitrary strings throughout the lowering. Use a small
backend-local IR with typed value IDs, statement variants, blocks, functions,
members, globals, and a single renderer. It should model only the contract
above, not reimplement MLIR or VeIR.

Public API sketch:

```lean
def LLZK.compile
    (cfg : LLZK.Config F)
    (name : String)
    (circuit : FormalCircuit F Input Output) :
    Except (Array LLZK.Diagnostic) LLZK.Module

def LLZK.Module.render : LLZK.Module → String
```

## 7. Execution phases and acceptance gates

### P0 — Tool and contract spike

1. Make a current LLZK 3.0 `llzk-opt` and `llzk-witgen` available through a
   pinned Nix result or trusted binary cache.
2. Hand-write `Addition8FullCarry.llzk` against the contract above.
3. Run:
   - `llzk-opt Addition8FullCarry.llzk -o /dev/null`;
   - `llzk-opt --verify-roundtrip Addition8FullCarry.llzk -o /dev/null`;
   - `llzk-witgen ... --backend=interpreter`;
   - `llzk-witgen ... --backend=execution-engine`;
   - both witness modes with `--check-output`.
4. Cross-check several inputs against Clean `Circuit.witgen`.

**Exit:** the syntax, field behavior, input/output JSON, table containment
shape, and both witgen backends are empirically locked.

Important non-claim: `llzk-witgen` executes `compute()` and ignores
`constrain()`. It validates witness generation, not preservation of Clean
constraints or lookups.

### P1 — Lean skeleton and assertion-only circuit

Implement `IR`, `Print`, `Analyze`, generated layouts, and field-expression
lowering. Compile an assertion-only circuit with no lookups and only direct
field witnesses.

**Exit:** deterministic golden text, LLZK parse/verify/round-trip green, Clean
and LLZK witness outputs equal.

### P2 — Addition8FullCarry end to end

Add the recognized div/mod witness shapes, output member mapping, boolean
assert expression lowering, explicit ByteTable export, `global.def/read`, and
`constrain.in`.

**Exit:** compiler output is semantically equivalent to the P0 golden fixture
modulo stable normalization; both LLZK witgen backends agree with Clean.

### P3 — General structured witness subset

Add straight-line `Step`s, field inverse, field/natural conditionals, safe
casts, lists/arrays, and `VExpr.mapRange` in individually gated increments.
Each increment adds a positive fixture and a negative capability diagnostic.

**Exit:** every accepted constructor has differential coverage; every rejected
constructor fails before rendering.

### P4 — Table and layout API

Generalize `ExportTable.ofStatic`, add duplicate/name/arity checks, and decide
whether Clean should retain export metadata in `RawTable`. Add optional
source-name schemas without changing generated-name stability.

### P5 — Lowering assurance

Define executable semantics for the backend-local LLZK subset and prove:

- rendered field-expression evaluation agrees with Clean `Expression.eval`;
- accepted witness lowering agrees with `WitgenIR.eval`;
- assertion lowering preserves zero constraints;
- lookup lowering preserves membership under the supplied table registry;
- generated output indices agree with the `FormalCircuit` output variables.

This proof track can begin before VeIR is ready. Later connect the local
semantics to registered VeIR LLZK semantics.

## 8. VeIR track, revised

### Immediate use

- Treat the same `.llzk` fixture corpus as VeIR input.
- Upstream VeIR can preserve unknown LLZK operations/types with
  `--allow-unregistered-dialect`; this is useful as a generic MLIR
  round-trip check, not an LLZK semantic check.
- The project fork can additionally recognize its registered Felt/Bool/
  Constrain.eq subset.

### Do not sync the fork yet

The July 10 recommendation to sync upstream before Array work is stale.
Comparing the project branch with current upstream shows substantial
two-sided divergence, and upstream is currently refactoring verifier
ownership into dialect-local `OpInfo`. First perform a dedicated rebase audit:

1. inventory the fork-only LLZK commits;
2. classify them as replay, redesign, or obsolete against upstream 4.32;
3. prototype one small dialect replay using the new dialect-local verifier
   pattern;
4. choose between rebasing the fork and maintaining a downstream LLZK package
   that defines its own composite operation-info universe.

### Registered LLZK milestones

After that decision:

1. replay Felt/Bool/Constrain/Function/Global/Cast;
2. add `!struct.type`, Struct ops, and verifier rules;
3. add `!array.type`, Array ops, and `constrain.in`;
4. add field, struct, and array runtime values;
5. implement compute interpretation and compare with LLZK 3.0;
6. consume the frontend fixtures as the drop-in acceptance suite.

Directly importing VeIR into Clean should be reconsidered only when the two
projects share a supported Lean toolchain and the needed LLZK dialects are
registered. Until then, the textual contract is the correct boundary.

## 9. Conformance matrix

| Gate | Proves | Does not prove |
|---|---|---|
| Clean `#assert_exportable` | no native witness closures | LLZK lowerability |
| backend `analyze` | contract-subset and table/layout preconditions | renderer correctness |
| Lean golden/unit tests | deterministic construction/rendering | C++ acceptance |
| `llzk-opt` parse + round-trip | current LLZK syntax and verifier acceptance | witness equality |
| `llzk-witgen` interpreter | executable compute semantics in reference interpreter | constraints |
| `llzk-witgen` execution engine | lowered/JIT compute agreement | constraints |
| Clean vs LLZK witness diff | compute outputs agree on fixtures | universal correctness |
| lowering theorems | semantic preservation for proved subset | unsupported constructors |
| registered VeIR diff | independent Lean semantics agree | C++ passes outside corpus |

## 10. First commit-sized slice

Once P0's current LLZK tool is available, start with:

1. `Clean/Backend/LLZK/IR.lean`;
2. `Clean/Backend/LLZK/Print.lean`;
3. `Clean/Backend/LLZK/Basic.lean`;
4. one assertion-only fixture and deterministic golden test;
5. one integration script that fails closed if current `llzk-opt` or
   `llzk-witgen` is missing.

Then land Addition8 support as the next slice rather than placing all
expression, witgen, table, layout, and command work in one change.
