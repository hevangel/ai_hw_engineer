# Implementation plan: Am3101

1. Record original-device asynchronous operation, inversion, open-collector
   semantics and deselected-write X row before writing RTL.
2. Implement 16x4 storage with level-sensitive write using `always_latch`.
   No host clock/reset or initialized memory.
3. Implement the manufacturer's output table and explicit mode-valid metadata.
4. Verify a symbolic `anyconst` address against a one-word history oracle,
   including unrelated-address writes and read inversion. Prove output modes.
5. Exhaust address/data/selection/write combinations in simulation, continuously
   update data during a write, and test two-chip wired open-collector expansion.
6. Run clean lint, BMC/prove/cover, four-state simulation, and Yosys synthesis.
