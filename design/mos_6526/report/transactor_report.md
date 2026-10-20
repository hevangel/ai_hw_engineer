# Original Timer B/read-ICR loss detector

`scripts/run_transactor.sh` passes the original 104-byte Transactor payload,
two selectable CIA profiles, an unchanged independent CIA implementation
and an unchanged recovered-transistor CPU oracle. Verilator 5.052 executes
the native CPU with two actual CIAs and original KERNAL/BASIC ROM routines.

## Measured runs

Clocks below count the post-reset observation window; the two reset clocks
are outside that window.

| Mode | Loss profile | Target | CPU clocks | Original error stars | Original NMI entries | RDY holds |
|---|---|---|---:|---:|---:|---:|
| RTL | Affected | A | 1,000,000 | 0 | 1,171 | 6,628 |
| RTL | Affected | B | 1,000,000 | 1 | 1,171 | 6,612 |
| RTL | Unaffected | A | 1,000,000 | 0 | 1,171 | 6,628 |
| RTL | Unaffected | B | 1,000,000 | 0 | 1,171 | 6,611 |
| Independent CIA | Affected | A | 1,000,000 | 0 | 1,171 | 6,628 |
| Independent CIA | Affected | B | 1,000,000 | 1 | 1,171 | 6,612 |
| RTL plus transistor CPU | Affected | A | 500,000 | 0 | 584 | 3,286 |
| RTL plus transistor CPU | Affected | B | 500,000 | 1 | 584 | 3,325 |

For affected RTL, a Timer B event exactly one clock after the ICR read
produces a witnessed masked read; the original handler itself prints the
star. The unaffected run reaches an adjacent read/underflow but does not
lose the flag. The test asserts presence/absence of original error stars,
not a count copied from the RTL. Counts above are measured diagnostics.

The transistor runs compare **999,948 exact bus cycles** after bootstrap:
address, RW and every write-data byte, with identical RDY/IRQ/NMI inputs
and settled read data. This includes the actual flag-loss event. The adapter
only supplies external pins/read data; original transistor tables and
simulation sources are unchanged.

## Source and profiles

VICE SVN revision 45243 archives
[ciatest64.bas](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/CIA/transactor/ciatest64.bas),
its tokenized PRG, Makefile and
[attribution/physical observations](https://svn.code.sf.net/p/vice-emu/code/!svn/bc/45243/testprogs/CIA/transactor/readme.txt).
The readme attributes it to George Hug, Transactor, February 1989, page 62,
and reports affected and unaffected physical chips. The test extracts DATA
bytes unchanged, checks length 104 and the program's own sum 11949, and
executes them at the original 3200 address. It does not translate the test
into a new behavioral detector or edit its interrupt handler.

`TIMER_B_READ_LOSS=1` selects the affected legacy-latency profile; zero
selects the same interface without this defect. Zero does not model a fast
8521/new CIA. The marker follows pinned independent VICE
[`cia_do_update_tb` and ICR-read logic](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciacore.c):
an adjacent earlier ICR read marks a B event, the next ICR read hides that
flag, and a clean new B event replaces the marker. Other sources and D7
are not hidden. The source-backed register/IRQ pipeline remains unchanged.

The independent software result uses unchanged zlib-licensed
[`m6526.h`](https://github.com/floooh/chips/blob/9e88298ce56319953ac7a43213a1120359f7a3a6/chips/m6526.h)
at commit `9e88298ce56319953ac7a43213a1120359f7a3a6`, SHA-256
`327a362b9b2235af55c0af712c527bce068633c98f76cdc0c8c4bb35e1d47393`.
The original license/header stays in ignored reference files. This is an
independent result for this detector, not an every-cycle whole-CIA oracle.

All source/ROM downloads are SHA-256 pinned. Original BASIC 901226-01 is
8,192 bytes, SHA-256
`89878cea0a268734696de11c4bae593eaaa506465d2029d619c0e0cbccdfa62d`.
Firmware retains its owners' copyright and is not committed/relicensed.

## Phase coverage and exact execution

The original KERNAL restores vectors and initializes both CIAs. A declared
bootstrap performs the BASIC SYS-equivalent call, then enters the original
BASIC WAIT routine at B840 with WAIT 198,7 argument state. Normalization
instructions establish CPU registers before comparing the transistor model;
CPU state is never forced over a call. Tests assert exact reset/bootstrap
PCs/opcodes, the original payload RTS and its exact following instructions,
original NMI entry 3248/48, and original exit JMP 3265 to FEBC/68.

The initial three-cycle idle loop and even the original WAIT loop alone
never reached the adjacent read/underflow in this fixed-raster fixture.
Therefore those zero-star probes did not establish the absence of the
defect. The permanent test applies a one-cycle RDY read hold every 127
observation clocks only within B83E-B848. This legal phase sweep runs with
both profiles and the independent CIA unchanged. CIA clocks continue while
the CPU holds. It is an explicit missing-board phase-coverage input, not
a claimed VIC-II DMA implementation. Original payload/handler bytes and
read-loss window are not adjusted to manufacture the result.

## Remaining requirements

Direct formal and two-simulator tests cover both profiles, all 1,024
mask/source combinations, exact read offsets and clean-event recovery.
The eleven original Lorenz programs still pass. Physical subcycle windows,
CNT/cascade-mode loss traces, device/revision identification, remaining IRQ
races, TOD reset differences and serial synchronizer timing remain open.
All four complete systems remain pending.
