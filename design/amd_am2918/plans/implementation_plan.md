# Implementation and verification plan

1. Specify original CP/Q/Y/OE contract from primary truth table before RTL.
2. Implement four native D flip-flops and independent Y gating; no reset.
3. Formal proof of rising-edge capture, all other phase holds and independent
   Q/Y/OE; reachable covers for both enabled/disabled capture and idle gating.
4. Exhaust all16 pre-states, all16 data words and both OE values. Change data
   during steady HIGH/LOW CP and on falling edges to detect latch behavior.
5. Reconstruct original two-chip bidirectional circuit and eight-bit serial
   converter; exhaust bus/state/control combinations and all256 initial serial
   words crossed with all256 eight-bit input streams.
6. Run unsuppressed lint, BMC/prove/cover, simulation and synthesis/check.
   Document sourced historical uncertainty and actual test counts.
