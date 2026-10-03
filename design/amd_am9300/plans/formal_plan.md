# Formal plan: Am9300

An external harness carries its own four-stage case-table reference with
separate per-bit assignments. Reference and DUT use physical CP/MR edges.
`multiclock on` with `clk2fflogic` allows asynchronous reset and freely
changing CP, rather than proving only a sampled synchronous reset model.
Assume an initial asserted MR; subsequent input transitions are unrestricted.

Assert DUT/reference agreement and complementary Q3 on the global formal
clock after initialization. Reachable covers include parallel 0xA, a serial
one arriving at Q3, Q0 hold, Q0 toggle, and asynchronous reset of nonzero
state while CP remains high. Run BMC, unbounded induction, and cover tasks.
