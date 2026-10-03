# Implementation plan: Am9300

1. Establish the physical reset and K polarities from the original symbol
   and truth table. Write the specification before RTL.
2. Use four flip-flops with native rising CP and asynchronous low MR.
3. Use the JK characteristic equation for Q0 and a three-stage shift for
   Q1-Q3; select parallel input on low PE. Continuously invert Q3.
4. Prove against an independently transcribed case-table model, including
   arbitrarily timed reset and CP transitions through multiclock formal.
5. Exhaust all initial nibbles, parallel values, PE and JK combinations in
   pin-level simulation; check reset and held clocks between active edges.
6. Run lint, formal BMC/prove/cover, simulation, then Yosys synthesis. Update
   the report and index only with actual evidence.

The hardware width remains four: changing it would model a different part.
