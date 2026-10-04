# Am2903 verification report

The full digital design implements 505 documented nine-bit words: 496 normal
source/function/destination combinations and nine special functions. Source
Tables1–5 were independently transcribed before RTL; the 1979 manufacturer's
correction to the special-E carry-generation cell is explicitly cited.

## Final combined run

`sh design/amd_am2903/scripts/run_all.sh` in ai-hw-engineer:latest:
Verilator5.052, Yosys0.69, SymbiYosys ABC/Z3.

- Independent formal-table regeneration check passed.
- Verilator `-Wall -fno-dfg` RTL/native fixture/four-slice software builds
  pass with the specific native-latch/cascade annotations described below.
  Pure combinational datapath lint has no exceptions.
- Native simulation: 415,104 vectors and 12,591,489 checks passed. Covers
  every documented word × eight source controls × three physical roles ×
  sixteen pin/data states (193,920); all sixteen normal ALU functions across
  every R/S/Cn/role (24,576); and all destinations/F/Q/shift-pin/role patterns
  (196,608). Every case initializes through native pins, reads all sixteen
  RAM words, probes Q/SC and checks LOW-phase read holding. WE operates
  independently of decoder WRITE, including simultaneous RAM writes/Q loads.
- Formal BMC16, unbounded PDR and all sixteen cover traces: PASS. Generated
  gold logic covers every datapath signal from external CSV expressions;
  native assertions cover legal CP phases, symbolic watched RAM, write-data
  equivalence, Q/SC edges and enables. No reset or power-up values assumed.
- Real software: original Figures17/19 microcode ran 139,464 products,
  2,370,888 executed words and 30,821,547 exact microcode/state checks. Each
  program covers all 65,536 eight-bit operand pairs, 100 full-width boundary
  pairs and 4,096 deterministic full-width pairs on four actual slices plus
  actual Am2910. Tests assert the next fetch and exact post-instruction PC
  at each edge, including 12-bit wrap. The final manufacturer X control is
  concretely CONT, with that choice documented rather than claimed original.
- Synthesis/check passes: 1,157 hierarchical cells (743 datapath), 72 native
  latch bits (64 RAM/8 read ports), five Q/SC FF bits, and five model input
  capture latches. Check reports zero problems. Twenty-one Yosys warnings
  are expected: one memory lowering and twenty deliberate latch-process
  messages. Two ABC combinational-network advisories are also visible.

## Clock sampling and lint scope

The suite caught zero-delay read-latch reopening changing Q-load data before
Verilator's FF evaluation for simultaneous external WE/Q load. Five explicit
LOW-transparent input capture bits preserve the manufacturer pre-edge Q/SC
sampling order. They respond during the LOW phase and hold at the edge;
formal verifies Q/SC against the previous-phase table values. These extra
bits are a digital timing adapter and their area is not historical die area.

Local UNOPTFLAT annotations cover core `ram_input`, `y_o`, `shift_o`, and
fixture `carry`, `z_bus`, `z_pull`. Native complementary-latch paths are
phase-separated; bidirectional shift/parity and open-collector routes are
acyclic for each legal instruction but a mode-insensitive graph joins
opposite directions. No blanket lint category suppression or unused-signal
suppression is used. Unannotated raw lint may warn on these structural paths.

## Limits

No electrical delay/contention model or defined reserved-special-code
semantics. Introduction year is a sourced availability bound by1978, not an
exact first-shipment date. Multiply programs are original AMD application
firmware; normalization/division special instructions are verified by the
manufacturer table oracle and formal, without claiming a separate complete
historical division application regression. Conditional IEN only promises
the documented state/WRITE inhibition; continuing combinational data is the
explicit decoder/ALU assumption in the spec.
