# IBM PC 5150 verification report

Date: 2026-10-14. Target: original 1981 IBM 5150, 64 KiB RAM, CGA,
two single-sided 160 KiB drives, original April 24 BIOS, Cassette BASIC 1.00
and PC DOS 1.00. See the [specification](../spec/spec.md) and
[immutable reference hashes](../spec/reference/README.md).

## Implementation and independent oracle

`src/ibm_pc.sv` connects the existing 8086 execution unit to a new byte-wide
bus/four-byte queue, and actual 8259, 8253, 8255, 8237 and 8272 RTL. The C++
boundary stores RAM/ROM bytes and responds as decoded rotating diskette media.
It does not decode CPU instructions or intercept BIOS/DOS interrupts.

The original IBM ROM listing and unchanged software are independent oracles.
No BIOS patch, CPU state injection, disk interrupt shortcut or self-written
instruction model is used in historical-software tests. A monitor counts
entries into the manufacturer's BIOS diagnostic printer, so a later screen
clear cannot conceal a POST error. The boot test requires zero diagnostics.

The local web panel renders actual VRAM with the original CGA character ROM.
Physical and on-screen keys produce make/break codes for the PPI latch and
IRQ1. Power, reset, run, pause and instruction step operate the persistent RTL
process. Mounted media remains in memory until exported; original drive A is
initially write protected. The speaker viewer measures the real PIT-derived
output period.

## Verification

Run `sh system/ibm_pc/scripts/run_all.sh` in `ai-hw-engineer:latest`.
The flow checks the complete FDC and DMA first, then the board and software/backend,
then synthesizes the complete digital board hierarchy.

The final checks below passed. During integration they were run as individual
component commands after each relevant repair; this is not a claim that the
earlier aggregate attempt, which exposed FORMAT failure, passed. The final
component logs below are the recorded evidence for this revision.

| Final result | Recorded outcome |
|---|---|
| Complete FDC flow | PASS; 75,432 checks per seed (1/42/2026), Verilator and Xezim; 58 checks at 4 MHz in each; BMC/PDR/all eight cover goals, UVM and synthesis pass |
| Complete DMA flow | PASS; 350,723 checks / 66,889 transfers in each simulator; BMC/PDR/all 11 cover goals, UVM and synthesis pass |
| Board lint, bus formal, CPU/adapter and speaker tests | PASS; three bus cover goals, exact instruction PCs and nominal 440 Hz output |
| CPU/DMA format and VERIFY | PASS; all eight sectors, final-ID TC, normal results, exactly 4,096 filler writes and 4,096 verify pseudo-transfers |
| Original POST / disk bootstrap | PASS at 97,000,000 clocks / 6,600,825 instructions; zero BIOS diagnostics |
| Original FORMAT.COM | PASS; all 40 tracks formatted and verified, completion at 273,000,000 clocks |
| COPY / directory / independent FAT12 comparison | PASS; exported file bytes exactly equal original TIME.COM |
| BASIC / DONKEY | PASS; expression 42, return to DOS, original title, CGA graphics and frame change after key input |
| Backend controls | PASS; actual RTL, including concurrent pause/poll and disk mount/export |
| Whole-board Yosys synthesis | PASS; 101,196 generic cells, zero structural-check problems; array-to-register lowering warnings retained |

The historical regression ended at 328,000,000 clocks / 18,361,875 retired
instructions, with 4,798,847 DMA cycles (4,550,271 refresh), 487,936 media read
bytes, 169,984 media write bytes, zero CPU faults and zero BIOS diagnostics.
These are functional simulation counters, not original-silicon performance.
Both peripheral UVM flows report zero errors/fatals; installed-library name
warnings remain (27 for FDC, 25 for DMA).

| Check | Evidence |
|---|---|
| Strict Verilator build/lint, complete hierarchy | `work/build.log`; `-Wall --assert`, no warning suppression |
| Bus BMC / PDR / cover | `work/formal/`; depth 24 / unbounded / depth 32, three cover goals |
| CPU board program | Exact final CS:IP, ordered aligned/odd word bytes, ROM protection, PIC aliases, switch configuration, keyboard acknowledgment and physical drive selection |
| Four-byte prefetch queue | Exact retirement PCs; stale queued NOP survives RAM modification, taken jump fetches the new HLT |
| CPU/DMA/FDC format program | Eight sectors, 32-byte ID DMA, final-byte TC, 4,096 correct filler writes, drive A unchanged |
| CPU/DMA/FDC VERIFY | 4,096 DACK-only pseudo-transfers, normal result and unchanged RAM |
| Speaker wiring | Actual CPU programming of PPI/PIT channel 2; measured output 439–441 Hz for a nominal 440 Hz divider |
| Original software | `work/software_frames.txt`, `work/software_final.json`, `work/software_trace.log` |
| Public HTTP interface | `work/backend.log`; power/step/run/pause/reset, concurrent poll/pause, scan-code validation, invalid requests, disk mount/export |
| Synthesis | `work/synth/ibm_pc.log` and JSON netlist; Yosys hierarchy, synthesis, ABC and `check -assert` |

Final component summaries: `work/fdc_final.log`, `work/dma_final.log`,
`work/board_final.log`, `work/disk_test.log`, `work/software_final.log`,
`work/backend.log`, `work/synthesis.log`; bus proof status is in
`work/formal/ibm_pc_bus_{bmc,prove,cover}/`. All artifacts are ignored build
products and regenerate from the checked-in scripts.

Bus formal proves queue-count bounds, valid fetch pops, no CPU strobe while
DMA owns the bus, and grant inhibition. Cover reaches a full queue, simultaneous
pop/refill and DMA ownership. These safety properties are not a proof of every
CPU instruction or all IBM motherboard behavior.

The historical-software regression cold boots through POST and disk bootstrap,
enters the date through keyboard IRQs, and exercises COMMAND, DIR, CHKDSK,
FORMAT, COPY, BASIC and DONKEY. A separately written FAT12 reader compares the
bytes of the DOS-created file against its original source file. Program tests
assert meaningful output, disk activity and CGA frame changes.

## Integration defects and prevention

Original BIOS exposed controller command rejection with pending READY events
and IRQ batching that could hide a later seek edge. Manufacturer command rules
and independent MAME behavior pin the repair. The board also required READY
tied high, correct cassette/speaker separation, a two-phase PIC acknowledgment,
DMA-exclusive FDC selection and physical drive selection from the DOR.

A new real CPU/DMA test found that TC on the final format ID omitted the final
sector even though result status was normal. Regression checks now cover both
the chip handshake and the whole track's actual disk bytes. Details:

DOS also exposed the DMA core dropping CPU mode writes during pending refresh,
before HLDA, and the FDC requiring RD even for DMA VERIFY. Intel explicitly
permits S0 programming and requires VERIFY data strobes inactive. Completed
DACK consumption is an explicit FDC digital-interface assumption validated by
the board regression and unchanged software.

- [READY-event post-mortem](../../../failure_notes/2026-10-14-intel8272-ibmpc-ready-events.md)
- [Format-TC post-mortem](../../../failure_notes/2026-10-14-intel8272-format-terminal-count.md)
- [DMA programming post-mortem](../../../failure_notes/2026-10-14-intel8237-pending-grant-programming.md)
- [Controller verification report](../../../design/intel_8272/report/final_report.md)

## Limits

This is a functional virtual platform, not a transistor/electrical recreation.
The shared EU does not reproduce native 8088 instruction clock counts or all
undocumented NMOS differences. RAM is static model storage, although refresh
PIT requests and actual DMA acknowledgments execute. Keyboard input begins at
the completed scan-code boundary. Disk media is standard decoded PC160K, not
raw flux or arbitrary physical track layouts. CGA supports standard text and
graphics modes; custom raster tricks and composite artifacts are outside scope.

External cassette recordings and optional serial, printer and game adapters
are absent. Speaker output uses measured pitch, not an exported transition
stream. ROMs/font/OS retain their copyrights and are downloaded to ignored
cache, not redistributed. Passing these finite tests does not establish
universal software compatibility, silicon equivalence or FPGA timing closure.
