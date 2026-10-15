# Intel 8272A verification report

Verification date: October 14, 2026 (America/Vancouver), including the original IBM PC integration corrections. Scope: the [specified virtual-drive functional core](../spec/spec.md), not physical package compatibility. Three synthesizable modules implement the host/sector controller, FM/MFM word codec and IBM CRC.

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

The [coverage report](coverage_report.md) records actual measured totals and remaining gaps. Physical drives and raw track/flux parsing remain unverified. The [IBM PC virtual platform](../../../system/ibm_pc/README.md) now runs original BIOS/PC DOS with the actual 8237 DMA core. GPL and track layout remain backend responsibilities. Event ordering, scan FF masking, zero head-timer semantics, conflicting recalibration direction prose, backend timing, scan result CHRN advancement and initial polling IRQ batching are explicit assumptions A1–A8. In particular, normal scan result-ID advancement and initial IRQ batching have no physical Intel-silicon measurement. Format result IDs are architecturally undefined and deterministic only for this model.

Within the documented boundary, internal regressions resolved TC write-byte retention, late ND final-byte service, physical-head status, scan retry/status/deadline/EOT behavior and invalid Read Track header counter handling. These findings came from the design's own verification/review; there is no claimed external hardware sign-off.

Original 1981 IBM BIOS subsequently exposed two escaped READY-event defects:
valid SPECIFY/Sense Drive commands were rejected while other polling results
were queued, and separate initial polling IRQs could obscure a later seek edge.
Manufacturer command rules and independent MAME reset behavior pin the fixes.
The new regression acknowledges only one initial READY result before issuing
those commands, preserves remaining results, and confirms completed SEEK still
requires SIS. Initial polling now batches one IRQ. A separate 4 MHz regression
checks doubled 26 µs service/overrun, polling and 2 ms minimum seek timing.
See the [post-mortem](../../../failure_notes/2026-10-14-intel8272-ibmpc-ready-events.md)
and [system verification report](../../../system/ibm_pc/report/final_report.md).

System disk tests subsequently found a final format ID with TC skipping its
sector's filler field and DACK-only VERIFY not consuming read bytes. The
former now retains the accepted ID and completes the data field. The latter
uses completed DACK as a read-consumption fallback while preserving normal
RD timing and Intel's strobe-free DMA VERIFY operation (assumption A8).
Both have chip regressions and a real CPU/8237/FDC board test. See the
[format post-mortem](../../../failure_notes/2026-10-14-intel8272-format-terminal-count.md).

## Recorded results

The complete flow ended with `8272 COMPLETE FLOW PASSED` and exit status zero.

| Check | Recorded result |
|---|---|
| Strict lint, three RTL modules | PASS |
| 32-cycle BMC / unbounded PDR | PASS / PASS |
| Four cover tasks | PASS; all eight goals reached |
| Verilator seeds 1 / 42 / 2026 | PASS; 75,432 checks each |
| Xezim seeds 1 / 42 / 2026 | PASS; 75,432 checks each |
| 4 MHz service/seek test, both simulators | PASS; 58 checks each |
| Independent codec, both simulators | PASS; 4,102 checks each |
| UVM scoreboard / opcode bins | PASS; 203 reads / 15 of 15 bins |
| UVM errors / fatals / name-check warnings | 0 / 0 / 27 |
| Controller statement / branch / toggle coverage | 81.79% / 83.87% / 54.11% |
| Generic synthesis cells: controller / codec / CRC | 6,444 / 76 / 45; all checks pass |

All eight cover goals remain reached. Repeated procedural fragments account
for 780 measured statements and 279 branch arms. Cell counts are generic Yosys
cells with no FPGA/ASIC technology mapping. The final chip rerun's primary log is
`system/ibm_pc/work/fdc_final.log`; chip artifacts reside under `work/formal`,
`work/sim`, `work/uvm`, `work/clock`, `work/codec`, `work/coverage` and `work/synth`.
