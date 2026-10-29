# IBM PS/2 Model 30 verification report

Target: original 1987 8530-021, 8 MHz 8086, 640 KiB RAM, MCGA, one
720 KiB diskette drive and a type-26 integrated 20 MB fixed disk. The
optional 8530-002 two-floppy configuration remains a regression target.
Verification date: October 18, 2026.

## Execution boundary

The native maximum-mode 8086, its six-byte BIU, interrupt acknowledgements,
8237 DMA, 8272 FDC, PIT and all BIOS/DOS instructions execute in RTL.
The C++ host supplies external memory chips, decoded disk media, keyboard
bytes and trace storage. JavaScript renders actual VRAM, palette and font
state. No instruction interpreter, ROM patch, BIOS/DOS interception or
host-side CPU-register injection is used for historical software tests.

Original ROM socket archives and disk images are hash pinned by
`prepare_images.py`; see the [source manifest](../spec/reference/README.md).
Their copyrighted bytes and generated traces remain in ignored `work/`.

## Completed checks

| Check | Measured result |
|---|---|
| Strict Verilator 5.052 traced build | PASS with `-Wall --assert` |
| Bus conversion formal | Depth-24 BMC, unbounded PDR and 4/4 covers PASS |
| Full-board Yosys 0.69 synthesis | PASS; 210,657 generic cells, zero structural problems |
| DBA controller bounded formal | Depth-32 BMC and 5/5 control-handshake covers PASS |
| CPU/DMA3/fixed-disk fixture | PASS; 107,782 clocks, 2,048 DMA transfers, 1,036 media writes, IRQ5 and exact HLT PC |
| Drive controller tests | PASS; 53,217 checks including external ECC/CRC vectors, bursts, retries, extended checks, ID/format, ND buffer operations, DMA blocks and short TC |
| Fixed-disk persistence/capture | PASS; three captures equal ordinary DMA execution; payload/ID/raw-check bundles survive process restart, invalid checksum rejected without mutation |
| Exact-PC CPU board fixture | PASS; native/odd memory lanes, split word I/O, DMA clock crossing/page readback, ROM protection, RAM mapping, MCGA/DAC/font, keyboard commands, UART loopback/IRQ, RTC and reset retention |
| CPU/DMA/FDC fixture | PASS; 6,576,987 clocks, 9,252 DMA transfers, 4,608 media writes |
| Original fixed-disk install/boot | PASS; FDISK/restart, full FORMAT /S, COPY, CHKDSK, independent FAT16/file comparison, cold C: boot with zero floppy reads and copied-program execution |
| Original application workload | PASS; original EDLIN create/edit/backup bytes, BASICA prime sieve/save/reload/square root, return to DOS; 557,250,000 clocks, zero CPU faults or POST errors |
| Original graphics software | PASS; BASICA SCREEN 2 interleaved rectangle and BIOS modes 13h/11h exact full-framebuffer comparisons through original DEBUG |
| Configured-clock reboot | PASS; unchanged POST and DOS return to COMMAND.COM after CPU/board reset, zero POST errors |
| Battery storage | PASS; CPU-written 32-byte RTC image survives process restart/reset; invalid size rejected |
| Waveform execution equivalence | PASS; six captures at 1/4,096/65,536 clocks equal ordinary execution, including CPU state, RAM hash, VRAM/font/palette/RTC and counters |
| HTTP backend | PASS; power/run/pause/step/reset, keyboard, mount/export, bounded captures, atomic FST download, HEAD, timing and self-hosted Surfer |
| Original 5150 regression after shared PIT/PIC repairs | PASS through DOS tools, whole-disk FORMAT, COPY/FAT12 comparison, BASIC and DONKEY |
| 8259A manufacturer request-withdrawal regression | PASS; 5,867 cycles, 41,128 field checks, 38 proof outputs and 9/9 covers |

The drive-controller unit test uses reduced 4-cylinder/2-head/3-sector
geometry to exercise every FORMAT DRIVE transition. Full type-26 geometry
is used by the CPU DMA fixture and original BIOS/DOS tests.

The diskette fixture formats all nine sectors on head 1 of physical drive B
from DMA page 5, performs VERIFY without writing RAM, then reads every E5h
byte into page 6. It checks normal FDC result bytes, exact terminal count,
the exact post-HLT PC and untouched drive A/other tracks. This test caught
and prevents a refresh/DMA grant deadlock.

Synthesis reports 32 unique warnings (55 instances) from lowering arrays
to registers, including existing chip arrays. Structural `check -assert`
reports zero problems. Cell counts are generic synthesis results, not area
or timing closure for a particular FPGA or manufacturing process.

The bridge proof assumes the native BIU's legal phase progression and bus
ownership held through T2/T3/Tw/T4. It proves conversion safety under that
contract; it is not a whole-machine proof. Each cover exercises a native
word memory cycle, paired word I/O, paired video memory, or INTA.

## Historical software status

Original POST reaches `640KB OK`. A fresh battery image produces the
legitimate `161-Set Date and Time` notice; no hardware diagnostic remains.
F1 resumes and original PC DOS sectors transfer through FDC/DMA. Original
DIR/CHKDSK and the full 160-track floppy FORMAT pass, with 730,112 usable
bytes. COPY writes CHECK.COM and an independent BPB/FAT12 reader verifies
720K geometry and exact file bytes. BASICA evaluates 6*7 as 42.

The separate display run boots configured BIOS/DOS with zero POST errors
at 234,000,000 clocks. BASICA SCREEN 2 draws the exact interleaved rectangle
at 270,750,000 clocks and returns to DOS. Original DEBUG assembles BIOS
INT 10h/INT 16h calls: mode 13h matches all 64,000 expected pixel bytes at
357,500,000 clocks; mode 11h matches all 38,400 bytes at 418,000,000 clocks.
Both return through the BIOS keyboard wait to DEBUG in text mode. A full
CPU/board reset then passes unchanged POST with the retained battery clock,
boots DOS at 236,000,000 clocks and reaches COMMAND.COM after accepting
the normal date/time prompts at 239,500,000 clocks, with zero POST errors.

The floppy FORMAT/COPY/BASIC-expression stages and display stages were run
separately. The initial driver incorrectly requested BASICA SCREEN 13,
which the original interpreter rejects. The corrected driver uses supported
SCREEN 2 and original DEBUG/BIOS calls for native MCGA, with paced scan
codes to respect the original 16-byte BIOS keyboard buffer. The aggregate
entrypoint includes the corrected scripts; an uninterrupted aggregate run
is not claimed.

`test_software.py` exercises cold POST, original PC DOS 3.30, DATE/TIME and original DEBUG.COM executing BIOS RTC setters,
DIR/CHKDSK, FORMAT/COPY with an independent FAT12 comparison, BASICA and
a configured-clock reboot. `test_display_software.py` exercises BASICA's
supported CGA graphics and original DEBUG executing BIOS INT 10h in native
MCGA modes 13h and 11h. BASICA's SCREEN numbers do not include 11/13; see the
[independent BASICA/GW-BASIC language reference](https://robhagemans.github.io/pcbasic/doc/2.0/).
The aggregate `run_all.sh` always includes this real-software regression.

## Escaped defects

- [PIT Mode 0 rearm](../../../failure_notes/2026-10-15-pit-mode0-rearm.md):
  unchanged firmware exposed a shared timer bug. Directed dual-variant
  simulation and formal checks now enforce the manufacturer behavior.
- [Planar integration](../../../failure_notes/2026-10-15-model30-planar-integration.md):
  original POST exposed the 4 MHz DMA register handshake and missing floppy
  diagnostic/UART interrupt registers and scan-set persistence during LED
  updates. Board fixtures cover the repairs.

- [PIC request withdrawal](../../../failure_notes/2026-10-18-intel8259-withdrawn-request.md):
  FDISK's software reboot exposed a pending timer request retained after the
  source fell. Intel's priority-cell diagram pins the repair; literal tests
  and formal properties cover withdrawal and fixed-IR7 spurious vectors.
- [720K floppy identification](../../../failure_notes/2026-10-18-model30-floppy-identification.md):
  original FORMAT exposed an undocumented gate-array identification input
  returning the high-density value. Assumption A12 records the original
  BIOS evidence; rate selection and media bounds are now enforced.

- [MCGA mode 6 selection](../../../failure_notes/2026-10-18-model30-mcga-mode6.md):
  original BASICA exposed a valid high-resolution-only mode register value
  decoded as text. The native board fixture now checks its literal status
  and the historical graphics suite checks interleaved pixel memory.

## Functional limits

This is a digital functional virtual platform. Original electrical timings,
analog raster output, magnetic flux, DRAM charge decay and external keyboard
MCU firmware are outside its boundary. See the [assumption ledger](../spec/spec.md)
for the documented DMA-page manual/ROM discrepancy and inferred gate-array
details. Instruction timing follows the repository CPU contract rather than
claiming identical silicon cycle counts. The integrated fixed disk uses the documented DBA controller contract;
its exact MCU firmware and proprietary silicon implementation are outside
this platform. No 8087 is installed.

Verification establishes the listed cases and contracts. It does not claim
100% equivalence to every undocumented behavior of original hardware.

The current front panel emits scan sets 1/2. The normal original BIOS
selects set 1. Serial/parallel ports have register and loopback behavior;
external modem/printer devices are unconnected. No external mouse UI or
mouse MCU firmware is supplied. These optional external devices are not
part of the DOS configurations verified here.

## Fixed-disk installation evidence

Original DOS FDISK creates the active type-4 partition at LBA 17 with 41,531
sectors. Its own software restart passes the original BIOS without another
diagnostic at 412,000,000 cumulative clocks after the PIC repair. Original
FORMAT C: /S completes and transfers the system; its usable FAT16 capacity
is 21,204,992 bytes. An independent reader verifies both FAT copies, file
chains and exact IBMBIO.COM, IBMDOS.COM, COMMAND.COM and CHECK.COM bytes
against the original floppy.

The HTTP front panel boots this guest-created disk with A ejected, zero
floppy-media reads and zero POST diagnostics. It reaches C> and executes
the DOS-copied CHECK.COM, which reports 21,114,880 available bytes after
the installed files. A 4,096-clock live CPU capture also passes. The original
DOS date/time prompts are handled through keyboard scan codes; no BIOS
service or filesystem construction is performed on the host.

The fixed-disk installation stages finish at 1,136,000,000 cumulative CPU
clocks. The boot stage was repeated from that DOS-created bundle with
`test_harddisk.py --resume-boot` after correcting the normal DOS date/time
prompt handling. It reaches COMMAND.COM at 242,000,000 clocks and executes
CHECK.COM at 250,000,000 clocks, with 179,200 DMA transfers, zero POST
errors and zero floppy-media reads. Default `test_harddisk.py` runs both
stages; the resume option validates installed file bytes before starting RTL.


## Original EDLIN and BASICA application run

Additional application verification completed on October 19, 2026 with
`scripts/test_real_software.py`, on unchanged system/CPU RTL. The script
boots a private copy of the earlier guest-installed DOS disk; C: boot has
zero floppy reads and zero POST errors. It then mounts the hash-pinned DOS
floppy to execute the unchanged 7,526-byte EDLIN.COM and 36,403-byte
BASICA.COM applications. DOS/BIOS and application instructions run in RTL;
no external DOS-service fixture or CPU-register injection is used here.

EDLIN creates REAL86.TXT, closes it, reopens it, deletes/inserts line two
and closes it again. At 304,750,000 clocks an independent FAT16 reader
checks the exact edited CR/LF/1Ah bytes and the original .BAK payload.
COMMAND.COM TYPE reads the edited file at 310,250,000 clocks.

Original BASICA runs the new [prime workload](../tb/software/README.md)
using its software floating-point/array routines without an 8087. An
independent trial-division oracle requires 168 primes through 1000 and sum
76,127; this passes at 457,000,000 clocks. BASICA saves its tokenized program
to C: at 463,000,000 clocks. NEW discards the in-memory program and CLS
clears the prior output before LOAD reads the DOS-saved file. The repeated
calculation passes at 547,000,000 clocks. INT(SQR(2)*1000000) returns
1,414,213 at 554,500,000 clocks. SYSTEM returns to DOS at 557,250,000 clocks,
with zero CPU faults and zero POST diagnostics.

The final application script passes uninterrupted. It prevalidates typed
source characters before POST and recognizes BASIC's final console prompt
above its original function-key legend. Its final disk bundle preserves
all original installed DOS file bytes as well as the independently checked
text/backup and saved BASIC program. Logs, frames, state snapshots and the
private disk remain under ignored `work/real_software*`. The full system
aggregate is still distinguished from the separately executed stages above.

The current [8086 complete verification flow](../../../design/intel_8086_8088/intel_8086/report/final_report.md#current-historical-software-rerun)
also passes, including the original Microsoft DEBUG application through all
three CPU interfaces and all 1,700,163 physical-chip instruction cases.
