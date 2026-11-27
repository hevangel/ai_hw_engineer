# Intel 80387SX

**First introduced: by November 1988 (Intel 80387SX data sheet 240225-002, as cited in issue #115). Status: planned profile. Its architecture is the 80387's, already implemented and verified in [intel_80387dx](../intel_80387dx/README.md). The 16-bit host-bus interface has not been built.**

The 387SX is the math coprocessor for the 386SX. It has the 80387's programming model and numerics behind a 16-bit data bus in a PLCC package. Hosts in this program include the IBM PS/2 Model 35 SX, the Model 25 SX (candidate) and the Model 56 SLC. The month is taken from the data sheet's order-number revision, as cited in the issue; no Intel announcement date was located.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Report](report/final_report.md)
