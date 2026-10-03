# Intel 8272A verification report

Verification date: October 2, 2026 (America/Vancouver). Scope: the [specified virtual-drive functional core](../spec/spec.md), not physical package compatibility. Three synthesizable modules implement the host/sector controller, FM/MFM word codec and IBM CRC.

## Implementation

All 15 commands are present: Read Track, Specify, Sense Drive Status, Write Data, Read Data, Recalibrate, Sense Interrupt Status, Write Deleted Data, Read ID, Read Deleted Data, Format Track, Seek and the three scans. The controller supports four independent seek engines, ready polling/events, head timers, command/result processing delays, DMA and non-DMA byte service, deleted marks, multi-head addressing, TC, short DTL transfers and status/error results. Physical track parsing, PLL, gap generation and electrical timing remain external.

## Reproducible flow

Use the repository `ai-hw-engineer:latest` Docker image and run:

```sh
sh design/intel_8272/scripts/run_all.sh
```

Tool versions used: Verilator 5.052 (2026-09-05), Xezim 0.11.0 (git 6558a1e), Yosys 0.69 (git 9f75ca1f9), SymbiYosys 0.69 and Z3 5.1.0. Logs, binaries, waveforms, coverage databases and generic netlists are retained under ignored `work/`. Each script fails if the expected completion marker is absent; this matters because a simulator can report a fatal test failure yet return a zero process status.

RTL lint runs `verilator --lint-only -Wall` separately for all three modules, with no RTL warning suppressions. Testbench-only waivers cover procedural clock/test stimulus, initialized test variables and deliberately unobserved interface signals. Generic synthesis runs hierarchy checks, synthesis and `check -assert` separately for all modules; the result is not a device-specific timing, LUT or electrical implementation claim.

## Regression scope

The standalone suite runs seeds 1, 42 and 2026 in both Verilator and Xezim. Fixed manufacturer-table result/status values are compared with the host bus; generated and seeded media content is independent of requested CHRN. Directed checks cover:

* All commands, invalid opcode, empty SIS, held command/result strobes, RQM/DIO, ND byte IRQ and first-result IRQ acknowledgement.
* DMA DACK before RD/WR, DMA data with CS inactive/A0=0, full N=0–6 sector reads, CRC drain after TC, and the final ND byte pending across sector-end.
* Ordinary/deleted writes, TC's accepted byte followed by zero fill, short DTL reads/writes, deleted mark stop/SK behavior, MT side switching and all eight head/MT/EOT Table 8 combinations.
* Read ID, Read Track index gating/nonsequential IDs, supplied format CHRN/filler/trailing index, equality/order/masked scans, mixed comparison failure, STP=2 retry, SN clearing on a later hit, deleted scan skip, normal failed scan at reachable EOT and TC search abort.
* Wrong cylinder/FF bad cylinder, missing data mark, ID/data CRC, missing headers after two indices, protection, fault, loss of ready, overrun and exact MFM read deadline. Scan timeout checks the read deadline separately from write service.
* Four overlapping seeks with exact 200/201/202/203 pulse counts and inward direction, SIS PCN/unit ordering, successful recalibration and exactly 77 outward pulses on failure, startup polling events and HLT/HUT boundaries.

The UVM environment uses factory registration, a Config DB virtual interface, sequence-generated transactions, a protocol driver, passive host-read monitor, expected/actual scoreboard and dedicated command coverage collector. It checks 203 host reads, including a complete 128-byte ND sector and fixed results for all command opcodes. The standalone suite provides detailed media write/scan checks. The UVM command covergroup has 15 bins; it does not imply every opcode/flag/timing cross was covered. The library produces 27 component-name validation warnings with UVM_NO_DPI; these are reported rather than silently discarded.

The codec suite checks 1,024 normal encoding vectors against retained upstream Greaseweazle functions, byte decoding and prior/last bit behavior, missing-clock FM/MFM marks, CCITT known answers and zero residue. It performs 4,102 checks per simulator. [Reference provenance](../references/README.md) identifies the independent source and CRC oracle.

## Formal claims

BMC explores 32 cycles of arbitrary host/media input widths following initial reset. PDR checks the same safety invariants without a depth bound: command/result indices, result-index stability without accepted read, data-request/result-phase gating, reserved result bits, sector size and byte count, and recalibration count. `byte_count <= sector_size <= 8192` implies the maximum byte count. No cover stimulus constrains safety tasks. The harness accelerates RQM to one tick and millisecond timers to one tick per millisecond.

Eight cover goals use four separate legal command prefixes: invalid result, media search, DRQ, seven-byte result, write execution, ND pending byte, seek step and SIS result. This establishes non-vacuity of those paths, not proof of all command semantics, IRQ priority, data content or physical timing.

## Limits and assumptions

The [coverage report](coverage_report.md) records actual measured totals and remaining gaps. The design has not been verified with a physical drive, raw track/flux parser, historical BIOS/operating system or an integrated 8237 DMA system. GPL and track layout are backend responsibilities. Event ordering, scan FF masking, zero head-timer semantics, conflicting recalibration direction prose, backend timing and scan result CHRN advancement are explicitly recorded as assumptions A1–A6. In particular, normal scan result-ID advancement is an emulator-corroborated convention, not Intel-silicon validation. Format result IDs are architecturally undefined and are made deterministic only for this model.

Within the documented boundary, internal regressions resolved TC write-byte retention, late ND final-byte service, physical-head status, scan retry/status/deadline/EOT behavior and invalid Read Track header counter handling. These findings came from the design's own verification/review; there is no claimed external hardware sign-off.

## Recorded results

The complete flow ended with `8272 COMPLETE FLOW PASSED` and exit status zero.

| Check | Recorded result |
|---|---|
| Strict lint, three RTL modules | PASS |
| 32-cycle BMC / unbounded PDR | PASS / PASS |
| Four cover tasks | PASS; all eight goals reached |
| Verilator seeds 1 / 42 / 2026 | PASS; 74,591 checks each |
| Xezim seeds 1 / 42 / 2026 | PASS; 74,591 checks each |
| Independent codec, both simulators | PASS; 4,102 checks each |
| UVM scoreboard / opcode bins | PASS; 203 reads / 15 of 15 bins |
| UVM errors / fatals / name-check warnings | 0 / 0 / 27 |
| Controller statement / branch / toggle coverage | 81.76% / 83.99% / 53.90% |
| Generic synthesis cells: controller / codec / CRC | 6,646 / 76 / 45; all checks pass |

Cover steps: invalid result 4, search 47, DRQ 51, seven-byte result 56, write execution 49, step pulse 30, SIS result 39 and ND pending byte 55. Repeated procedural fragments account for 773 measured statements and 281 branch arms. Cell counts are generic Yosys cells with no FPGA/ASIC technology mapping. The primary log is `work/final_flow.log`; per-task artifacts reside under `work/formal`, `work/sim`, `work/uvm`, `work/codec`, `work/coverage` and `work/synth`.
