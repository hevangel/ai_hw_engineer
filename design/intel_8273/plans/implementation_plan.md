# Implementation plan

1. Establish the Intel bus/command/result contract and functional boundaries in
   the specification before RTL.
2. Implement separate serial Tx, serial Rx and DPLL modules; integrate command
   handling, two data latches, modem controls and persistent results in the core.
3. Generate independent wire vectors from RFC 1662 framing rules and Python's
   C CRC oracle; exercise both directions and damaged/aborted frames, including
   the maximum 65,535-byte information length.
4. Add a two-controller serial link using the existing 8237A to move information
   bytes to/from actual testbench memory. Include that demo in run_all.
5. Add UVM bus/serial sequences, scoreboard and functional coverage; prove control
   invariants and run covers for frame completion, receive and error paths.
   Sweep DPLL receive sampling through all 32 initial phases at periods 31–33.
6. Run strict RTL lint, formal, dual-simulator regressions, coverage and synthesis;
   report measured results and explicit limitations, then submit a PR.
