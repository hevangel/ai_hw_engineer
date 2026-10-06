# Am9517 implementation plan

1. Audit original AMD register map, reset, pending programming, arbitration and
   memory-copy rules before adapting the existing Intel 8237A RTL.
2. Implement native active-high asynchronous reset, grant-time arbitration,
   pending programming, original hardware-only status request bits, software-only
   memory-copy initiation and no clear-mask command at E.
3. Adapt the broad manufacturer-directed simulation/UVM/formal suites; add focused
   AMD differences, asynchronous reset and delayed-grant request changes.
4. Run actual original 1979 STUP and SDMA programs on Am9080A with independent
   instruction oracle, exact PCs and independently checked DMA transfers.
5. Run lint, BMC/unbounded proof/nonvacuous cover, simulation/UVM and synthesis;
   document assumptions, original printing errors and actual results.
