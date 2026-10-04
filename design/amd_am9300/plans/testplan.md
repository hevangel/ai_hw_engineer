# Test plan: Am9300

Use an exhaustive pin-level `tb_top.sv`: load each of the 16 possible prior
states, then exercise both PE levels, all four physical JK combinations, and
all 16 parallel words. Expected serial Q0 comes from the AMD truth table,
not the RTL's Boolean equation. Check all four outputs and Q3 complement.

Also check that falling CP, data changes with CP low or held high, and reset
release do not advance state. Assert MR while CP is held low and while it
is held high; require immediate clear before another rising edge. Hold MR
low across clocks and data/mode changes, then recover into parallel load.
Cascade two parts by tying the second part's J/K-bar to first Q3: old Q3
must enter the second slice on the same rising edge. Check an eight-bit
stream against a single independently formulated shift vector.

These are discrete device pins, with no bus transaction interface or UVM
agent: direct exhaustive simulation is appropriate for the entire 4-bit
state space. An empty UVM scaffold would add no coverage.

Every mismatch is fatal; a bounded run must emit `TEST PASSED` to count as
successful. Functional bins require all 2048 transitions to be exercised.
