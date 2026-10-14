# IBM PC reference provenance

Primary hardware/firmware authority: IBM, [Personal Computer Technical Reference,
August 1981, 6025005](https://www.minuszerodegrees.net/manuals/IBM_5150_Technical_Reference_6025005_AUG81.pdf).
Use the motherboard schematics and I/O map, PPI and keyboard descriptions,
CGA interface and diskette adapter, and Appendix A's BIOS listing. The 1981
16–64 KiB board and BIOS are the target; later 256 KiB-board switch settings
must not be mixed with this firmware. The timer prose contains channel-label
ambiguities; the schematics and actual BIOS programming pin IRQ0 to counter 0
and refresh to counter 1.

`scripts/prepare_images.py` downloads original artifacts from these immutable
archive commits, validates their Git blob IDs and converts container data to
bytes without patches or reassembly:

- [PCjs](https://github.com/jeffpar/pcjs/tree/1a91d38eb12e5fdf91116b21ad9ef1935710a496),
  revision `1a91d38eb12e5fdf91116b21ad9ef1935710a496`: 1981-04-24 BIOS,
  Cassette BASIC 1.00 and CGA character ROM.
- [PCjs disk archive](https://github.com/jeffpar/pcjs-diskettes/tree/cd3433748b09837a4c60ca7066f3642772b2d711/pcx86/sys/dos/ibm/1.00),
  revision `cd3433748b09837a4c60ca7066f3642772b2d711`: original PC DOS 1.00.
  Its raw disk MD5 must also match archive metadata. Short sector arrays repeat
  the last dword, following that container's representation.

| Converted artifact | Bytes | SHA-256 |
|---|---:|---|
| BIOS | 8192 | `a259306c47b43e14ef6378d7bdeff67331a2519d363bc36b3f354bc91a6874c8` |
| Cassette BASIC | 32768 | `2452b03b4b724b5b81e8cc367809c521144f5fe4e0425caee42ac71240b9b102` |
| CGA character ROM | 8192 | `37527f661580e5a09710051cec67422abfadf31c61b841537a91e7f27be19304` |
| PC DOS 1.00 disk | 163840 | `29a4c5eb355b2bfb1dbbece96d91eabc5c1331c6299437d00dd8d862ac126eb2` |

The generated manifest retains source URLs and Git blobs as well. Firmware,
font and disk bytes retain their original copyrights; they are fetched to
ignored local cache, not redistributed in this repository. A separately
generated blank work disk uses the archive's PC160K FAT12 geometry: reserved
sector 0, FATs in sectors 1/2, 64 root entries in sectors 3–6 and data starting
at sector 7. It contains no copied operating-system files.

The Intel [8272A datasheet](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf)
pins the distinction between READY events and completed seeks and the doubling
of timing intervals at a 4 MHz controller clock. Independent
[MAME controller code](https://github.com/mamedev/mame/blob/031d99f427df935056d42fa943476ed1bfb8e879/src/devices/machine/upd765.cpp),
particularly `C_SENSE_INTERRUPT_STATUS` and `run_drive_ready_polling`, explicitly
documents the 5150 BIOS requirement for a single initial polling IRQ. Its
initial polling pass gathers all drive changes before raising that IRQ.
Manufacturer timing establishes the normal scan intervals; the reset batching
choice is recorded as a controller assumption and validated with real BIOS.

Intel's [8237A datasheet](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf),
“DMA OPERATION,” permits CPU programming in S0 until HLDA. It also defines
VERIFY as a pseudo-transfer with all memory/I/O strobes inactive. IBM's
unchanged BIOS uses that mode for disk verification. The FDC's completed-DACK
read-consumption fallback is explicitly assumption A8 and tested with the
real DMA core; the precise edge is not claimed as a measured silicon waveform.

CGA display decoding uses actual video memory, palette/mode and cursor/start
registers. The default thick 8×8 font is the ROM block at byte offset 1800h.
Reference containers, source extracts, converted images and the manifest are
retained under `work/reference/`. Download caches are never treated as executable
instructions for the coding agent.
