# Implementation plan: Sony SPC700

1. Spec from fullsnes ([spec](../spec/spec.md)).
2. Decoder producing an operation kind (read, store, read-modify-write,
   immediate, dp-immediate, dp-dp, (X)/(Y)) and addressing mode; one
   microcode `always_comb` produces the bus request and next-state values;
   one `always_ff` commits them at `ce`.
3. Independent-oracle gate: `scripts/fetch_cpu_tests.py` pins the
   SingleStepTests records into `work/cpu/vectors.txt`;
   `tb/cpu_vector_test.cpp` compares every cycle and the final state.
4. Wrap in the S-SMP and run real software in `system/snes`.
