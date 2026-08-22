# S29 Phase B — proved modulo and bitwise bounds

## Frozen implementation

- Implementation commit B:
  `7a0f209ca7806a0e97173ffe84b47b9aa1f20be5`.
- Parent: reviewed Phase-M evidence tip
  `2f2239f25271f3db958bf3d7d2022b2e3be59272`.
- Branch: `clean-to-llzk/s29-xor-range-contract`.
- Lean: `v4.32.2`.
- Accepted LLZK source: `25fb3740ea3465c9129a06289297bb4f0554b7a5`.
- Accepted LLZK output:
  `/nix/store/xlf4j9a1r756c8m6s7b7f88s8rqq7j58-llzk-release-3.0.0`.

B changes exactly six paths: the frontend bound analyzer, the independent
semantic reader/proof, three test modules, and the S29 theorem probe. The frozen
diff is 324 insertions and 27 deletions. A post-commit attribution check found a
clean worktree, a clean `git diff --check`, and no drift from the reviewed
six-path index.

## Implemented semantics

`U64Expr.upperBound` now treats literal division and literal modulo separately.
Division retains the recursively proved numerator bound. For nonzero literal
modulo, the analyzer first proves the numerator bound `ba`, then returns the
exclusive bound `min ba d`. This requires the numerator to remain syntactically
analyzable. The emitter and independent reader then recursively admit it, so a
small final remainder cannot hide an unsupported or unsafe numerator.

`lor` and `lxor` recursively prove bounds `ba` and `bb` for both operands and
return `2 ^ Nat.clog 2 (max ba bb)`, provided that envelope is at most `2^64`.
The recognizer's existing root check separately requires the result and every
recursively admitted child to remain at most the configured field prime.
Wide-field `.val` remains refused.

`LLZK.WExpr.eval_lt_upperBound` proves the modulo case with `UInt64.toNat_mod`,
`Nat.mod_le`, `Nat.mod_lt`, and `Nat.lt_min`, deriving positivity of the literal
divisor from the checked nonzero `UInt64` through `UInt64.toNat_inj`. The OR/XOR
cases use `Nat.le_pow_clog`, `Nat.or_lt_two_pow`, `Nat.xor_lt_two_pow`, and the
`UInt64.toNat_or/xor` evaluation lemmas. No circuit assumption, constraint,
lookup fact, trusted annotation, new axiom, or source-specific allowlist enters
either proof.
`eval_ofWitgen` and the G9 precondition of `compileSourceVerified` remain the
semantic bridge for the complete admitted witness expression.

As throughout the frontend theorem chain, this bridge is relative to D017's
existing `WExpr` reading of `felt.*`. Phase B does not supply a formal LLZK
semantics or a verified translator, and its Xor32/BLAKE3.G result is compile
capability only until Phase X/H exercises the external tools.

## Bound and refusal controls

The exact bound table pins modulo and XOR/OR behavior at 1, 2, 255, 256, 257,
`2^63`, and `2^64`, as well as asymmetric operand order. It separately pins the
Babybear raw XOR/OR ceiling at `2^31`, above the prime, and the narrowed ceiling
at exactly 256.

Fail-closed tests retain or add all of the following:

- asymmetric and symmetric raw `.val` XOR, and raw `.val` OR;
- a numerator that can reduce in the Babybear field before `% 256`;
- a distinct numerator that can wrap at `2^64` before `% 256`;
- loop-index, local-variable, dynamic, zero, prime, and above-prime modulo;
- exact bn254-width `.val % 3` and `.val % 256` analysis;
- G9 XOR-to-OR, wrong-XOR-operand, and wrong-divisor mutations.

Every existing and S29 G9 cross-mutation first proves a self-comparison green
for both expressions; Phase B added the missing baselines for the older
mutants too. This prevents an unreadable original or mutant from masquerading
as a successful discriminator. The capability sweep checks direct successful
compilation of Xor32 and `BLAKE3.G 0 1 2 3`; it does not treat an empty error
array as success. Keccak Theta retains exactly 50 raw-XOR diagnostics.

The external corpus and showcase definitions are intentionally untouched by B;
the complete matrix remained at 15 modules, 51 vectors, and 9 source-backed
entries. Xor32 and BLAKE3.G have not yet received independent fixed references,
shape guards, concrete table-resolution proofs, or `spec_of_compile`
instantiations, so Phase B makes no headline or promotion claim for them.

## Independent adversarial review

Three read-only reviewers continuously covered semantic soundness, process and
attribution, and red-control quality. Their confirmed findings were repaired
before B was frozen:

- modulo was required to analyze its numerator recursively; separate controls
  were required for hidden field reduction and hidden u64 wrap;
- G9 mutations required independent self-baselines and exact boundary rows;
- literal-modulo diagnostics initially mislabeled failed recursive numerators
  as dynamic divisors and were changed to describe the actual child failure;
- the first modulo table exercised only cases where the numerator bound was the
  smaller arm of `min`; maximal-numerator rows now prove the divisor arm;
- capability guards initially used an `.isEmpty` error check that could accept
  `.error #[]`; direct `.toOption.isSome` success checks replaced it.

After those repairs, all three reviewers returned GO on the exact six-file
index. The later post-commit attribution check likewise found no drift.

One diagnostic-quality boundary remains: if a nested zero or otherwise invalid
literal divisor appears beneath a parent whose root bound analysis also fails,
the emitted message can identify the parent as the first unsupported bound
rather than the deepest divisor. This is fail-closed and does not change
admission or the proof, but future diagnostic work may make the cause more
specific.

No branch was pushed, no issue or pull request was opened, and no external
state changed.
