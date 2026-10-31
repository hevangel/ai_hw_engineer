# Implementation and verification plan

1. Transcribe the ten manufacturer encoder truth rows and five output gate
   conditions before RTL. Preserve positive output polarity and separate EI
   from the five gates.
2. Implement a descending-priority combinational encoder and EO reduction.
3. Formal assertions use the primary truth table, independently of the loop
   implementation; run BMC/prove/cover without assumptions.
4. Exhaust all 256 request patterns, two EI levels and32 gate combinations.
   Exercise actual two-chip EI/EO cascading over all 65,536 request patterns
   and gate-release cases. Build nine actual chips into a 64-input hierarchy;
   verify each sole request, every request pair, boundary patterns and random
   simultaneous requests against a separate descending search.
5. Run unsuppressed Verilator lint, formal tasks, simulation and Yosys
   synthesis/check; publish sourced history and measured results.
