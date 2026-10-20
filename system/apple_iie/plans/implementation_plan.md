# Apple IIe implementation plan

1. Establish PAL/cycle-model composition and reset/memory contracts in the spec.
2. Connect authored CPU, MMU, IOU and PAL to main/aux RAM and pinned original ROM.
3. Verify bus cadence, bank selection/remap, keyboard/status and video addresses.
4. Boot real ROM and execute a keyboard-driven command; record escaped defects.
5. Add a local web panel driven by simulated scanner data and an E2E regression.
6. Run lint, formal BMC/prove/cover, both simulators, synthesis and real software;
   document observed results and limits before creating a PR for review.


Completed implementation: board RTL, directed scanner/banking regressions,
original-ROM BASIC and 80-column execution, independent xezim ROM test,
shared C transport and both live HTTP backends. Verification evidence and
scoped fidelity limits are recorded in [the report](../report/final_report.md).
