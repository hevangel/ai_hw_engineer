# Test plan: Am2505

Exhaust all 32,768 combinations of P, six physical X/overlap/sign bits,
three Y/overlap bits, four K bits, and Cn. Compare S0-S3 and Cn+4 for
every combination. Compare S4/S5 whenever the required X4=X3 tie holds
(16,384 cases). An independent signed coefficient oracle implements the
Booth table, fractional-overlap contribution, and caller carry correction;
the carry oracle independently enumerates magnitude selection.

Wire four real Am2505 instances as AMD Figure 8's 8x4 signed array:
two four-bit X slices in each of two Booth rows; lower Cn=Y1; upper Cn
comes from lower Cn+4; second-row K comes from first-row sums shifted by
two, while the first two output bits bypass the next row. Reinterpret
every data/carry pin for active-low operation.

Check all 256 X and 16 Y patterns, with K=-128,-1,0,1,127, in both
polarities (40,960 array cases), against signed 8x4 multiplication plus
signed K. No behavioral multiplication is substituted for an RTL slice
in the array. Every error/coverage shortfall is fatal; success requires
an explicit pass marker. Discrete combinational pins need no UVM bus agent.
