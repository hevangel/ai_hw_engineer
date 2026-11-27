# Implementation plan: Intel 80386 core and DX/SX profiles

Canonical issue: https://github.com/hevangel/ai_engineer/issues/116 (DX #274, SX #275).

## Milestones

| Milestone | Scope | Exit evidence | Status |
| --- | --- | --- | --- |
| M1 | Real-address mode, complete real-mode general ISA with 16/32-bit operand and address sizes, precise faults, real-mode interrupt delivery | Every pinned real-mode capture file replays except the listed open discrepancies; lint, formal, synthesis | Done except the listed open items and the software gate |
| M1b | Original-software gate | An unchanged historical real-mode program (e.g. a 386 machine BIOS POST path or DOS DEBUG) runs on the core against an independent emulator trace | Open |
| M2 | Protected mode: descriptor loads and caches, privilege levels, call/interrupt/trap/task gates, TSS task switch (386 and 286 formats), #TS/#NP/#SS/#GP error codes, IOPL and I/O permission bitmap, LOADALL (0F07), unreal-mode captures | SingleStepTests 386 unreal/protected sets when published; a PCE/QEMU-independent scenario oracle (as for the 286); Intel PRM chapters 6–9 | Planned |
| M3 | Paging: two-level page tables, TLB, CR2/CR3, page faults with error codes, accessed/dirty bits, WP semantics as on the 386 (no CR0.WP) | Directed oracle scenarios plus original paging software | Planned |
| M4 | Virtual-8086 mode, IOPL-sensitive instructions, V86 interrupt return | SingleStepTests virtual-mode set when published; DOS under a V86 monitor | Planned |
| M5 | Debug registers DR0–DR7 breakpoints, single-step trap, RF, INTR/NMI with interrupt shadows | Directed tests from the PRM chapter 12 rules | Planned |
| M6 | 386DX native bus unit: 32-bit D bus, BE3#–BE0#, BS16# dynamic sizing, ADS#/NA# pipelining, READY#, LOCK#, HOLD/HLDA, 80387 interface | Intel386 DX datasheet cycle definitions; a physical DX trace for timing | Planned |
| M7 | 386SX native bus unit (see ../intel_80386sx/plans) | Intel386 SX datasheet; SX trace | Planned |

## M1 structure

- `src/intel_80386_pkg.sv`: ALU, shifter, double shifter, condition codes and flag helpers.
- `src/intel_80386_decode.sv`: combinational instruction-format decoder.
- `src/intel_80386_divider.sv`: iterative divider.
- `src/intel_80386_core.sv`: fetch, decode latch, micro-sequenced execution, real-mode interrupt delivery.
- `tb/tb_replay.cpp`: Verilator bench that replays the capture records.
- `scripts/`: capture reader, vector preparation, gate scripts.

## Engineering rules carried forward

- Every behaviour not stated by the PRM gets an `ASSUMPTION:` tag and a spec entry, and is checked against real captures or software before sign-off.
- Fixes for capture mismatches cite the capture file and record that pins the behaviour.
- The open-discrepancy list is exact: the gate fails both on a new failure and on a listed record that starts passing.
