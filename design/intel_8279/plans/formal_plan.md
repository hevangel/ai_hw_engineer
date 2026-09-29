# Intel 8279 formal plan

`intel_8279.sby` has `bmc`, `prove`, and `cover` tasks. The safety properties assert reset state, legal prescaler and FIFO counts, bus output enable, IRQ derivation, and blanking during clear. Initial reset is assumed for one sampled cycle; later reset is unconstrained. BMC checks depth 24 and ABC PDR attempts unbounded proof with the production `SCAN_DIV=64`.

Cover mode uses `SCAN_DIV=1` and Z3 to reach display-clear busy/blanking on the real DUT from a reset state. Cover depth is 8. A passed cover establishes reachability, not full functional equivalence; the directed simulation tests externally visible FIFO and sensor behavior.
