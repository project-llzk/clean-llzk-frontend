This is a plonky3 backend to demonstrate how to integrate with circuits written in Clean. 

THIS IS A NOT-PRODUCTION-READY POC!

Overall workflow:
1. Import the circuit written in Clean, and convert it to a plonky3 air `MainAir`.
2. Generate a trace corresponding to the circuit.
3. Prove and verify under the plonky3 backend.

This workflow is demonstrated by the tests in this repo, specifically in [`tests/fib_tests.rs`](tests/fib_tests.rs).

## Running the test

The integration test generates a Fibonacci trace from Lean and proves it with plonky3:

```bash
cd backends/plonky3
(
  set -euo pipefail
  fib_list="$(cargo test --release --test fib_tests -- --list)"
  test "$(awk '/: test$/ { count++ } END { print count+0 }' <<<"${fib_list}")" -eq 1
  grep -Fx 'test_lean_circuit_end_to_end: test' <<<"${fib_list}" >/dev/null
  cargo test --release --test fib_tests -- --include-ignored --nocapture
)
```

Expected output: `test test_lean_circuit_end_to_end ... ok`.
