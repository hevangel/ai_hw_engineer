# Implementation plan

1. Establish Intel's register map, count convention and timing boundary before RTL.
2. Implement four base/current banks, mode, global byte phase, masks, requests and status.
3. Add priority arbitration and ownership grant/release, keeping software requests independent of masks.
4. Implement S1/S2/S3/wait/S4, transfer/service modes, carry/borrow and timing options.
5. Add memory copy/fill, Temporary, source count reload and phase-qualified EOP.
6. Prove safety/accounting, then run directed/random pin-level simulation and UVM.
7. Run strict RTL lint and synthesis, document evidence/limits, update index and open a PR.
