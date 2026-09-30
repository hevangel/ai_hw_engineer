# Intel 8008 verification report

Environment: `ai-hw-engineer:latest`, Verilator 5.052, Yosys, SymbiYosys.

| Check | Result |
|---|---|
| `verilator --lint-only -Wall` | Pass, zero warnings |
| Directed exact-PC regression | Pass: ALU, memory, branch, call/return, I/O, HLT, interrupt RST |
| Authentic SCELBAL versus independent SIMH-derived oracle | Pass: 200,000 retired instructions; 63 writes, 475 inputs, 637 outputs; full register/flag/PC/stack and final memory agreement |
| SymbiYosys PDR safety proof | Pass |
| SymbiYosys cover | Pass: retire, memory write, I/O write reached |
| Yosys generic synthesis and structural check | Pass, zero problems |

The independent model was translated from the downloaded SIMH 8008 implementation, not from the RTL. The real software binary comes from the SCELBI archive. The directed suite checks exact next PC, with no padding to tolerate ambiguous landing positions.

The implementation models the programming interface and synchronous transactions. Original two-phase pins, multiplexed bus timing, analog READY behavior, and board-specific interrupt injection timing remain outside scope; see [the specification](../spec/spec.md).
