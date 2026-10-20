# CIA historical software with original KERNAL

`scripts/run_software.sh` passes eleven unchanged public-domain Lorenz 2.15
CIA programs with original Commodore 901227-03 KERNAL firmware, plus the
two earlier isolated PB6/PB7 baseline runs. The KERNAL-backed executions
total **41,195,603 native CPU clocks** in Verilator 5.052. The original
programs select their old-CIA expectations; no table, instruction or case
is modified or skipped.

Both `run_software.sh` (affected default) and `run_software.sh 0`
(unaffected legacy-latency profile) pass all rows below with identical
diagnostic counts. These programs do not by themselves establish the
adjacent-read loss difference; the separate Transactor test witnesses it.

| Original program | CPU clocks | Target CIA reads | Target CIA writes |
|---|---:|---:|---:|
| cia1pb6 | 22,473 | 467 | 1,387 |
| cia1pb7 | 22,316 | 467 | 1,387 |
| cia1ta | 10,555,247 | 139,613 | 413,544 |
| cia1tb | 10,825,651 | 139,613 | 413,544 |
| cia1tab | 13,739 | 98 | 644 |
| cia1tb123 | 9,622 | 331 | 439 |
| cia2pb6 | 22,473 | 467 | 1,384 |
| cia2pb7 | 22,316 | 467 | 1,384 |
| cia2ta | 9,846,073 | 124,993 | 333,319 |
| cia2tb | 9,846,073 | 124,993 | 333,319 |
| cia2tb123 | 9,620 | 331 | 382 |

The two isolated baseline runs remain 20,566/20,409 clocks, each with 466
CIA1 reads and 1,377 writes. Their console/vector/I/O entry points execute
explicit RTS fixture instructions. KERNAL-backed rows above execute original
vector restoration, I/O initialization, timer setup and interrupt code.

## Provenance and reproducibility

`fetch_software.py` checks SHA-256 for every PRG, its original source and
common includes from [VICE SVN revision 45243](https://sourceforge.net/p/vice-emu/code/45243/tree/testprogs/general/Lorenz-2.15/src/).
The maintained Lorenz sources identify themselves as public domain.
The [original KERNAL image](https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c64/kernal.901227-03.bin)
is 8,192 bytes with SHA-256
`83c60d47047d7beab8e5b7bf6f67f80daa088b7a6a27de0d7e016f6484042721`.
Its firmware copyright remains with its owners. Original downloaded
artifacts remain in ignored `work/lorenz`; the ROM is not committed or
relicensed as project RTL. The
[recovered KERNAL disassembly](https://www.pagetable.com/c64ref/c64disasm/#FDA3)
independently identifies the executed I/O and interrupt dependencies.

## Actual environment and exact checkpoints

Two actual CIA instances at DC00/DD00 connect to the native NMOS CPU's
IRQ/NMI inputs. Driven GPIO pins loop back and undriven pins pull high.
Fixed raster reads keep execution in the border with no DMA. ROM/I/O
mapping is fixed; processor-port writes are retained in fixture RAM rather
than changing the map. TOD input is held low. These are explicit isolated
test assumptions; this fixture is not a complete C64.

The ROM bytes are read unchanged except for explicit fixture bus overrides:
reset-vector reads select RAM 0200, and console entry FFD2 returns RTS while
capturing output. A six-byte bootstrap executes JSR FF8A and JMP 080E.
Checks assert exact PCs/opcodes at 0200, FF8A, FD15, the RESTOR return at
0203 and the following program-entry instruction. The first two program
fetches must be 080E/A9 and 0810/85. No CPU state is forced over a call.
Every run must reach the original success store at 0843, with post-PC 0846
and next fetch 0846/A9. Failure-mailbox writes fail immediately.

The clock-mode programs execute instruction bytes directly from CIA
registers and validate their original return behavior; the fixture does
not replace those reads with ordinary RAM. Each program must perform real
reads and writes at its named target CIA. Transaction counts are diagnostic
measurements; an arbitrary shared minimum would incorrectly reject the
valid 98-read cascade program.

## Defects exposed and remaining scope

The larger programs exposed stale timer/control reads, omitted same-cycle
ICR source flags and an extra CPU-observed NMI cycle. The
[escaped-defect analysis](../../../failure_notes/2026-10-20-mos6526-current-cycle-reads.md)
records their source-backed corrections. The unchanged timer oracle also
checks the new current-cycle read outputs, not merely registered state.

Passing these eleven programs establishes their tested old-CIA timer,
port, cascade, clock-mode and NMI behavior in this stated environment.
It does not establish every old-CIA interrupt race, physical CNT/SP timing,
TOD reset profile, analog timing or a complete board/system. The separate
revision/capture gates in the [specification](../spec/spec.md) remain open.

The [original Transactor detector](transactor_report.md) now additionally
qualifies affected/unaffected Timer B loss profiles with a declared legal
RDY phase sweep, independent CIA code and the recovered transistor CPU.
This does not modify any Lorenz program or table.
