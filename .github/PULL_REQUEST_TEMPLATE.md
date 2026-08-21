## Claim changed

<!-- What capability, assurance statement, documentation, or boundary changes? -->

## Evidence

- Clean base:
- LLZK source/tool pin:
- Targeted checks:
- Full G0–G12 result or named reason it is not required:

## Assurance checklist

- [ ] Newly accepted syntax has a semantic justification, lowering, positive
  test, and negative boundary test.
- [ ] Source-to-module agreement, renderer round trip, and external-tool
  coverage remain applicable or their boundary is documented.
- [ ] The change adds no `sorryAx` to the frontend theorem closure; any new
  trusted dependency is named.
- [ ] `doc/llzk/GAPS.md` and `doc/llzk/DECISIONS.md` are updated when a claim or
  trust boundary changes.
- [ ] `doc/llzk/EXAMPLES.md` was regenerated when the conformance corpus changed.
- [ ] Emitted golden changes were inspected rather than accepted as evidence by
  themselves.
- [ ] Changes outside `Clean/Backend/LLZK/`, `Clean.lean`, and `Clean/Test.lean`
  are intentional Clean-core work or remain byte-identical to the accepted
  upstream base.

## Public impact

<!-- What will a Clean user, LLZK contributor, or formal-methods reviewer see? -->
