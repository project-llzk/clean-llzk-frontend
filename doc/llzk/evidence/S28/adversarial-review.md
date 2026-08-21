# S28 post-completion adversarial review

Date: 2026-08-22

Frozen result reviewed: `bb24f96f` (implementation `03bf2f9b` plus its clean
G0-G12 evidence).

Status: two confirmed findings repaired; clean post-repair G0-G12 rerun pending.

## Review method

The pass read the complete S28 delta from the S26 evidence tip, then attacked
the boundaries most likely to preserve a green happy path while weakening the
claim:

- the relationship among `Config.tables`, a public hand-built `Recognized`, and
  the globals/lookup shapes `lowerRecognized` actually emits;
- row boundaries in G9, including scalar splitting, column exchange, and a
  changed grouping with an identical flattened scalar bag;
- renderer readback of global dimensions/values, row construction, field type,
  and membership;
- certificate name, arity, ordered canonical rows, and heterogeneous carrier;
- the exact premise of the generic and And8 `spec_of_compile` theorems; and
- the 65,536-by-3 scale path, corpus attribution, warnings, and axiom closure.

## Confirmed findings and repairs

### S28-R1 — `lowerRecognized` validated one registry and emitted another

Severity: medium. This entry point is G12-confined and has no Clean circuit to
compare, but it produces corpus artifacts and its own contract said it validates
the table registry.

The frozen implementation diagnosed `cfg.tables`, then built globals from
`r.tables`. A hand-built `Recognized` with configuration `tables := #[]` and a
retained table named `"not a symbol"`, arity two, with one width-one row returned
`.ok`; `Module.render` returned text as well. Thus the new multi-column
representation supplied a second unchecked registry through the very escape
hatch whose comments claimed registry validation.

Repair: `diagnoseRecognizedTables` now diagnoses `r.tables`, requires every
retained table to occur unchanged in the already validated `cfg.tables`, and
checks each retained lookup's row-count/arity against its retained table. The
original attack is `malformedRecognizedRegistry` in `Test/Circuit.lean`; its
exact three diagnostics are pinned. Expression diagnostics still take
precedence, preserving the existing D011 negative controls.

### S28-R2 — the theorem claimed module lookup satisfaction but assumed source rows

Severity: high for assurance wording, medium for implementation. The limitation
was honestly named in `GAPS.md`, but contradicted the public theorem/docstring
claim and the S28 And8 instantiation's headline.

On the frozen result, `spec_of_compile` quantified `hlookups` over
`FlatOperation.lookups src.operations` in certified-row form. It did not accept
satisfaction of the ordered polynomial rows in the module reader's `C.lookups`.
Consequently the prose “the emitted lookup is satisfied” still required an
unproved bridge even after certificates gained name and arity equality.

Repair: `ConstraintSet.LookupRowsHold` states satisfaction over the actual
ordered rows in `C.lookups` and the same-named nested rows in `C.globals`.
`lookups_perm_of_agree` obtains G9's exact permutation, and
`lookupRows_of_agree` proves the bridge using that permutation, G9's exact
global agreement, `ExportTable.Certifies`' name equality, and
`Expression.eval_toPoly`.
`constraintsHoldFlat_of_emitted`, `spec_of_compile`, and both concrete headline
instantiations now take this module-reader premise. Explicitly named
`*_sourceRows` compatibility theorems retain the old interface without making
the stronger claim.

### S28-R3 — live comments still described the retired one-column/interface state

Severity: low.

Live backend comments still said only one-column tables reached the emitter,
that the lookup semantic theorem/composed chain did not exist, that public
compile did not demand certificates, and that `byteTable_lookup_iff` remained
uninstantiated. The session status also still said acceptance was pending after
the committed green run.

Repair: the current code comments, `GAPS.md`, decision/session status, and
confinement description now match the implemented row model and theorem
interfaces. Historical review/evidence files remain historical.

## Attacks that held

- G9 remains red for splitting a three-column query into scalar memberships,
  exchanging two query columns, and regrouping the first two table rows while
  preserving the complete flattened scalar sequence.
- The protected renderer remains red for a changed global shape, changed
  row-major order, a dropped/malformed `array.new`, a dropped `constrain.in`,
  and a wrong row field type.
- Registry analysis still rejects arity zero, empty tables, width mismatches,
  noncanonical values, invalid/colliding/duplicate names, unresolved lookups,
  and source/registry arity disagreement.
- `ExportTable.Certifies` still ties name, arity, and ordered canonical rows;
  `withBytesAndXor` carries arity-one and arity-three certificates together, and
  the full ByteXor certificate remains independent of the exported definition.
- The generic bridge introduces no `sorryAx`; its probe closure is
  `[propext, Classical.choice, Quot.sound]`. The concrete And8 chain retains
  only the already recorded Babybear native-decide facts and upstream And8
  bv-decide identity in addition.
- No XOR-family circuit was promoted and every measured D033 `lxor` refusal
  remains; the two out-of-assumption And8 vectors remain identified as compute
  agreement only.

## Focused validation

The repair tree passes:

```text
lake build --wfail Clean.Backend.LLZK.Test.Circuit
lake build --wfail Clean.Backend.LLZK.Test.Constraints
lake build --wfail Clean.Backend.LLZK.Test.Lookups
lake build --wfail Clean.Backend.LLZK.Test.Soundness
lake build --wfail Clean.Backend.LLZK.Test.Print
lake env lean doc/llzk/evidence/S28/probe.lean
bash scripts/llzk/check-confinement.sh
python3 scripts/check-consecutive-empty-lines.py
git diff --check
```

The final section will record the clean repair commit and full G0-G12 rerun.
