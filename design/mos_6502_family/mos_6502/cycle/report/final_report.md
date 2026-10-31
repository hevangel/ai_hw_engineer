# Authored documented NMOS 6502 verification

## Acceptance scope

All **151 documented NMOS opcodes** are implemented in authored SystemVerilog.
This includes binary/decimal arithmetic with NMOS flags, all documented
addressing modes, dummy cycles, old/new RMW writes, stack, JMP indirect wrap,
reset, IRQ/NMI, RDY and SO. Unsupported opcodes fault and hold; there is no
claim of undocumented/unstable opcode or transistor electrical equivalence.

## Verified gates

| Gate | Evidence |
|---|---|
| Strict Verilator 5.052 lint | `--lint-only -Wall` on the synthesizable core |
| SBY / Z3 | BMC, induction proof and non-vacuity covers; legal state, bounded progress, status representation, fetch/write exclusion and stalled sequencing |
| Independent documented instructions | **177,280** SingleStepTests cases; every bus address/direction/data, final registers/memory, exact next fetch and following instruction |
| Unsupported opcode policy | All **105** other bytes trap and hold without writes |
| Exhaustive arithmetic | **524,288** cases from unmodified pinned py65; every A/operand, both carries, binary and decimal ADC/SBC including invalid BCD |
| Independent physical pins | **648 scenarios / 116,501 compared cycles** against recovered NMOS transistors; IRQ/NMI priority and arrival, BRK hijack, branches, RDY, SO, warm reset |
| Directed retained regression | 1,536 memory loads, 2,048 BIT cases, **131,072 exact-PC branches**, flag controls, smoke fetch sequence |
| Early system integration | Existing RAM/keyboard tests and authored CPU A/Z keyboard echo pass |
| Klaus software | Success **PC 3469**, **30,646,180 fetches**, **96,241,381 cycles** |
| Historical Apple II Monitor | Authored physical H7 socket: screen clear, `300:A5 5A`, `300.301`, physical DRAM and keyboard, printed output and **107,520 visible pixels** |
| Historical cassette byte routines | Both polarities: seven bytes and physical DRAM readbacks each, 112 output transitions, **111 exact firmware cycle intervals** |
| Yosys synthesis | Generic synthesis and `check -assert`; **2,782 generic cells**, zero reported problems |

`sh scripts/run_all.sh` runs every mandatory CPU gate and returns success only
after original Monitor and cassette software execute on this authored core.
Raw downloaded artifacts, traces and logs remain in ignored `work/`.

## Corrections found during verification

Independent arrival sweeps pinned penultimate-cycle IRQ/NMI polling, the
same-page branch polling exception, retained requests across crossing branches,
late NMI vector cutoff, and address-high correction during RDY. These behavior
changes are grounded in the external transistor artifact rather than a model
derived from the RTL. The test adapter observes architectural latch commits
at phi1, while retaining bus comparisons at phi2.

The formal progress proof required a legal-state invariant in addition to the
state-graph rank. Constant decoder/rank ROMs are mapped before SMT generation,
avoiding arbitrary induction initial contents. Assertions were preserved;
BMC and cover checks independently establish reachability and non-vacuity.

## Practical limits

- Formal proves the stated safety/progress properties, not complete ISA equivalence.
- Asynchronous pins must meet the sampling contract; metastability and sub-cycle
  electrical timing are outside the synchronous model.
- Canonical project initialization and ideal clock/socket levels are explicit
  [assumptions](../spec/spec.md). Physical warm reset preserves registers.
- The motherboard still has unresolved dummy/uninitialized read samples;
  sampling them high is counted and does not certify electrical correctness.
- Complete analog Apple II fidelity, original 2513 dump agreement, full cassette
  acquisition, and undocumented CPU opcodes remain outside these passing gates.

Independent source revisions, licenses and regeneration method are in
[REFERENCES.md](../tb/REFERENCES.md). Historical introduction sources are in the
[chip overview](../README.md).
