# Am2901 verification report

Verified October 3, 2026 with Verilator 5.052, Yosys 0.69, SBY/ABC/Z3,
and OpenJDK 21 in the `ai-hw-am2901-verification` overlay of
`ai-hw-engineer:latest`. Reproduce with the README's image instructions and
`sh design/amd_am2901/scripts/run_all.sh`.

## Observed results

- Verilator `-Wall -fno-dfg` slice and four-chip fixture lint passes. The
  combinational ALU has no lint waivers. Native clocked-latch feedback has
  localized UNOPTFLAT annotations on `ram_input`, `f`, `cn4_o` and the fixture's
  sign/overflow feedback. These are structural paths through complementary
  transparent latches; they are **not** a blanket warning disable. Raw lint
  without those annotations reports apparent cycles. This exception is explicit.
- Independent emulator: 98,304 cases, including every 512-word encoding,
  every possible pair for each source/function and both carries, randomized
  initial RAM/Q, aliased addresses, both OE states and all shift inputs.
  2,064,394 output, storage and native-phase checks pass. All sixteen words
  are read after each case to check unrelated-word retention. Initialization
  occurs through actual chip writes. High/low transparent data/address tests
  and rising-edge Q tests pass.
- The immutable third-party emulator disagrees with the original status table
  in 38,865 of these cases. Its data/state/shifter behavior matches. The adapter
  logs the differences and uses sourced manufacturer equations for status;
  the original emulator files remain unchanged and hash-checked.
- Actual manufacturer 1975 microcode: 69,732 signed products, including
  exhaustive signed eight-bit input pairs on the 16-bit cascade, 100 extreme
  16-bit pairs and 4,096 deterministic random full-width pairs. All 1,324,908
  executed words follow the exact original sequence; all intermediate shifted
  partial products, Q values, numeric words, pin directions, preserved inputs
  and full signed products pass.
- Formal: all six BMC/prove/cover tasks pass. The ALU has depth-2 BMC,
  unbounded induction and ten reachable covers. Native storage has depth-16
  ABC BMC, unbounded PDR and five reachable covers. The anyconst watched
  address, port-latch retention, transparent selected writes, unrelated-word
  retention, Q updates and pin enables are checked without a fabricated reset.
- Yosys synthesis and `check -assert` pass: 604 cells including a 123-cell
  combinational ALU, 72 intentional latch bits (64 RAM, eight read-port), and
  four enabled Q flip-flops. The 19 visible warnings describe memory lowering
  and intentional latches; they are documented rather than counted as zero.

## Findings and formal/timing boundary

The initial formal netlist rejected the structural path through complementary
transparent latches as a combinational loop. The FORMAL-only write-data cut is
arbitrary but **assumed equal to the actual computed write data at every step**;
this converts the netlist path into an equivalent constrained relation. Normal
RTL is unchanged. Legal setup/hold inputs are stable across clock transitions;
they remain arbitrary during either transparent phase. Covers reach actual
writes, unrelated writes, three Q update modes and RAMA's differing output.

Original microcode first exposed a zero-delay board-fixture race: Q3's
externally generated F0 could change as read latches reopened at the Q edge.
Holding the pre-edge external shift value across that edge satisfies the
documented physical input timing. Re-running the full flow passes. The
assumption ledger's timing contract is validated by this original program
and dedicated native-phase tests; it remains the user's board obligation.

This reconstructs the documented Am2901A digital interface. Analog delays,
electrical characteristics, unspecified power-up contents and a separate
microprogram sequencer are not part of the slice's guarantee.
