# Intel 8008 verification report

Environment: `ai-hw-engineer:latest`, Verilator 5.052, Yosys, SymbiYosys.

| Check | Result |
|---|---|
| `verilator --lint-only -Wall` | Pass, zero warnings |
| Directed exact-PC regression | Pass: ALU (register, immediate, memory), memory, conditional jumps/calls/returns in both senses, call/return, I/O, HLT entry/wake/re-halt, interrupt RST, undefined INR/DCR M NOP |
| Authentic SCELBAL versus independent SIMH-derived oracle | Pass: 200,000 retired instructions; 396,409 reads, 63 writes, 475 inputs, 637 outputs; full register/flag/PC/stack and final memory agreement |
| Opcode-family coverage | 15/19 families from authentic SCELBAL; union with directed tests 19/19 (see [coverage report](coverage_report.md)) |
| SymbiYosys PDR safety proof | Pass: retirement contract per opcode class, RET-alias/conditional-return stack behavior, RST push, CAL push, bus strobe/address correctness, ready freeze, undefined INR/DCR M no-effect ([formal plan](../plans/formal_plan.md)) |
| SymbiYosys cover | Pass: all cover points reached, including RTc/RFc fetch, injection from HLT, RST under interrupt |
| Yosys generic synthesis and structural check | Pass, zero problems |

The independent model was translated from the downloaded SIMH 8008 implementation, not from the RTL. The real software binary comes from the SCELBI archive. The directed suite checks exact next PC, with no padding to tolerate ambiguous landing positions.

## Review corrections applied (2026-10-23, issue #59)

- **Undefined INR/DCR M (octal 070/071)** indexed one past the register array while still updating flags. The core now commits register writes through a single guarded write port, making the out-of-range write structurally impossible; the encodings retire as NOPs with no flag change, and both a directed test and a formal property pin that behavior.
- **True-sense conditional returns (RTc, octal 2xx family: 0x23/0x2b/0x33/0x3b) decoded as NOPs** — the previous mask fixed opcode bit 5 to zero, so only RFc decoded; the SIMH-derived oracle implements both senses, and the manual defines RTc as `001 c4c3 011`. The mask now reads the sense bit. The defect was invisible to the SCELBAL regression because its single RTc executes not-taken; the directed test now covers both senses.
- **Formal proof scope** was labeled honestly and strengthened: the proof previously checked only strobe mutual exclusion and ready freezing; it now proves the per-opcode-class retirement contract above. The report table previously read "Pass" where the content was structural-only.
- Sequencer rewritten to the 4004's single-write-per-element discipline: next state is computed combinationally and committed once; no blocking locals, no side-effecting tasks inside the clocked block.

Known shared-modeling deviations are documented in the spec (stack wrap depth, undefined INR/DCR M flag behavior in SIMH).

The implementation models the programming interface and synchronous transactions. Original two-phase pins, multiplexed bus timing, analog READY behavior, and board-specific interrupt injection timing remain outside scope; see [the specification](../spec/spec.md).
