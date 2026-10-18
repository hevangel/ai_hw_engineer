# IBM PC XT 5160 with 8087 and 10 MB fixed disk

## Target and authority

Build a separate 1983 IBM 5160 virtual platform: 8088 architecture at nominal
4.772727 MHz, 256 KiB RAM, CGA, an installed Intel 8087, two 360 KiB floppy
drives and one IBM/Xebec-attached 10 MB fixed disk. Original November 8, 1982
XT BIOS, Cassette BASIC 1.10, IBM 1982 Xebec option ROM and PC DOS 2.00 execute
unmodified. Primary authority is IBM's April 1983 5160 Technical Reference:
https://minuszerodegrees.net/manuals/IBM_5160_Technical_Reference_APR83.pdf .
Independent controller contract evidence is pinned PCjs `hdc.js` plus the
original IBM option-ROM program; exact artifacts belong in the source manifest.

## Hardware contract

Reuse the verified 8086 execution unit behind the PC's four-byte prefetch,
eight-bit bus adapter, PIC, PIT, PPI, DMA, decoded FDC and CGA. Extend the ESC
observation interface with full ModR/M, instruction pointer and WAIT state.
The 8087 consumes those real CPU events and owns memory through arbitration;
CPU WAIT observes actual coprocessor busy. Pending commands must not be lost.
The installed math-coprocessor equipment bit and exception path must be
validated by original POST and CPU-executed coprocessor programs.

RAM is 00000h–3FFFFh, CGA aliases are B8000h–BFFFFh, fixed-disk ROM starts
at C8000h, and original BASIC/BIOS reside at F6000h–FFFFFh. ROM writes are
ignored. Refresh/DMA and numeric memory accesses have exclusive ownership.

The fixed-disk adapter decodes 320h–323h, uses DMA channel 3 and IRQ5, and
implements the original six-byte DCB protocol, initialization parameters,
status/result/sense, read/write/verify/seek/recalibration and diagnostics.
Media is decoded bytes at 306*4*17*512 = **10,653,696 bytes**; it is not a
10 MiB generic file or an IDE device. Cylinder/head/sector bounds and absent
drive 1 must generate controller errors. The original ROM installs INT 13h;
host code must never intercept BIOS/DOS interrupts or interpret CPU opcodes.

## User interface and persistence

Provide a local front panel with CGA, physical/on-screen keyboard,
power/reset/run/pause/step, CPU/FPU state and waveforms. Expose diskette
mount/export and fixed-disk export. Keep the hard disk writable and retain
it across reset and server restarts; explicitly document image location,
initialization and export. Boot PC DOS from the fixed disk, with a valid
partition/boot sector and DOS system files. Original DOS must demonstrate
directory, file writes and readback through the actual controller/DMA path.

## Assumptions and verification

- ASSUMPTION XT1: transaction-level ESC wiring replaces native 8087 queue
  snooping/RQ/GT pins. The 8087's documented numerical limitations remain.
- ASSUMPTION XT2: fixed-disk media is decoded sectors, without MFM flux,
  spindle mechanics or analog ECC faults. Controller commands, DMA, IRQ and
  original option-ROM execution remain real RTL behavior.
- ASSUMPTION XT3: functional CPU/bus timing, static RAM, completed keyboard
  scan codes and standard CGA rendering follow the 5150 platform boundary.

Run lint, controller formal assertions with cover, integrated ownership assertions, synthesis,
original XT POST, original fixed-disk ROM initialization, original DOS boot,
hard-disk file write/reboot/readback, actual CPU/8087 calculations and UI
backend regressions. Any existing-chip bug discovered by firmware requires
a failure note and an independent chip regression. Record evidence and
limitations honestly before a review PR; never patch historical firmware.
