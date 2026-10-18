# Model 30 integrated fixed disk

The user requested adding a hard drive to the 8086 Model 30. Target the
factory **8530-021** configuration: one 720K floppy and the original
20 MB fixed disk, with optional second-floppy support retained for the
existing board/media regression. Preserve mounted/exported floppy images
when changing the front panel.

## Authority and identity

IBM's [April 1987 product reference](https://bitsavers.org/pdf/ibm/pc/PS2_and_IBM_PC_Product_Reference_Version_4.0_Apr87.pdf)
identifies the 8530-021. The [May 1987 architecture paper](https://www.bitsavers.org/pdf/ibm/pc/IBM_Personal_Computer_Seminar_Proceedings/PC_Seminar_V05_N01_198705.pdf)
describes the integrated controller, onboard microprocessor, dual 512-byte
buffers, 48-bit ECC, DMA 3, IRQ5 and five 8-bit register functions. It states
that this register interface differs from the PC/XT and PC/AT interfaces.
The Model 30 [Technical Reference](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf)
pp.1-106/107 defines the dedicated 44-pin channel, planar select and device
presence. Its BIOS drive type **26** has **612 cylinders, 4 heads and 17
512-byte sectors**: 41,616 sectors / 21,307,392 bytes, marketed as 20 MB.

The independently drawn 1991 [Model 30 maintenance schematics](https://www.ardent-tool.com/docs/pdf/schematics/m30_sch.pdf),
sheet 6, corroborate the 44-pin HDU connector's eight data lines, IRQ5,
DREQ3 and DACK3. This is a third-party planar drawing, not a manufacturer
drive-controller datasheet, and does not identify the ICs inside the drive.

No single discrete controller IC part number has been verified. IBM calls
it a highly integrated chipset. Implement the documented drive-controller
contract in `model30_fixed_disk`, rather than inventing a chip identity.
Drive MCU instruction firmware, analog servo and magnetic-channel signals
are outside this digital decoded-sector platform.

The same DBA command/block protocol is documented in IBM's
[PS/1 Drives chapter](https://ftp.infania.net/pub/DOS%20Drivers/IBM%20PS1/Section%208.%20Drives.pdf),
pp.8-5..8-23. This later document has different drive geometry and IRQ14;
use the original Model 30 geometry and IRQ5. Cross-check the unchanged
Model 30 ROM routines at F000:F4FC..F57D and the independent 86Box
[`hdc_xta_ps1.c`](https://github.com/86Box/86Box/blob/ceb009f17daeecbb81e1ddf26ad63beda9300afe/src/disk/hdc_xta_ps1.c)
Model 25/30 variant. Do not copy emulator implementation code into RTL.

## Registers and control blocks

- 320h DATA: byte stream for CCB/CSB/SSB/format/data; supports PIO and DMA.
- 322h ASR read: transfer enable bit0, interrupt request bit1, busy bit2,
  direction bit3 (controller to host), data request bit4.
- 322h ACR write: DMA enable bit0, interrupt enable bit1, reset bit7.
- 324h ISR read: hardware check bit0, recovery bit1, reject bit5, invalid
  command bit6, unsuccessful termination bit7. Reading acknowledges status.
- 324h ATTENTION write: CCB bit7, CSB bit6, SSB bit5, data ready bit4.
  Invalid combinations must report an error; never silently hang DMA.

CCB has six bytes: command/ND/AS/EC flags; head plus cylinder high bits;
cylinder low; sector; size (02h); count. CSB and SSB have 14 bytes. The SSB
reports error flags, last ID, physical position, correction/retry counts,
command progress and type 26. CSB selects recovery enable and retry limit.
Support READ, VERIFY, READ EXTENDED, READ ID, RECALIBRATE, WRITE,
WRITE VERIFY, WRITE EXTENDED, FORMAT DRIVE, SEEK/PARK and FORMAT TRACK.
Format descriptors have five bytes per sector plus even-byte padding.
Preserve custom IDs and defective-track markers in external media metadata.

Data transfers use the real 8237 on channel 3, including its page register
82h, DACK, IOR/IOW and terminal count. The planar must select FDC data for
channel 2 and fixed-disk data for channel 3. Simultaneous requests must
retain independent media and interrupt state. No BIOS/DOS interception.

## Media and persistence

The host stores raw 512-byte sectors, ID descriptors and raw six-byte check
fields; controller operations, checksum generation/correction and command
progress execute in RTL. Ordinary images start with canonical CHS IDs and
error-free decoded sectors. Extended writes preserve supplied check bytes.
Persist the disk and its metadata atomically on pause, reset, power-off and
clean exit; support public mount/export and floppy eject/reinsert. Ejecting
A must retain its bytes and allow the original bootstrap to boot from C.
Never prebuild a DOS filesystem or patch the MBR/BIOS on the host: original
FDISK, FORMAT /S and COPY perform installation through the hardware model.

## Assumptions and verification

- A8: The original Model 30 disk supplement is not yet located. Port and
  block layouts are cross-checked between the original ROM, IBM's later DBA
  specification and independent Model 25/30 emulation. Nominal bounded
  digital command/sector delays are functional, not physical seek timing.
- A9: The 48-bit Fire-code generator and framing initial state are derived
  from the pinned independent emulator. Validate external known vectors,
  long transfers, CRC mode, correctable bursts and uncorrectable errors.
  Original IBM documentation promises correction of bursts up to 16 bits.
  Native tests cover lengths 1/2/8/16 at eight data/check boundary positions.
- A11: Power-up sector-buffer contents are unspecified. A no-data WRITE
  requires a prior completed read/write to establish valid buffer contents;
  reject an uninitialized buffer. Native tests validate ND read/copy/write.
- A10: CCB count zero is reserved for this target unless an original artifact
  establishes another meaning; reject it rather than guessing 256 sectors.

Add exact-PC CPU fixtures for reset/sense, PIO, DMA 3, nonzero pages,
head/cylinder rollover, invalid CHS, abort/reset, format IDs and ECC.
Include storage/capture equivalence, persistence and backend tests. Run
unchanged POST, DOS FDISK/FORMAT/COPY, independent FAT16 comparison and boot
from the installed C drive. Record actual results and unresolved boundaries
in the system report; no 100% silicon-equivalence claim.

## Backing-store format and independent vectors

The server saves `work/harddisk-<port>.m30`. A complete bundle contains
8 ASCII bytes `M30DISK1`, 21,307,392 payload bytes, 499,392 metadata bytes
and an 8-byte little-endian FNV-1a-64 consistency checksum of payload and
metadata. Each physical sector has 12 metadata bytes: five ID/format
bytes, six raw check bytes and a check-valid flag. Total: 21,806,800 bytes.
Mount validates the entire bundle before changing live storage. A raw
image establishes canonical IDs/checks; export a complete bundle when
preserving nonstandard IDs or intentionally damaged check fields matters.

`tb/hdd_check_vectors.hex` was generated by independently compiling the
unaltered `ecc48_generate` and `crc16_generate` functions from the pinned
86Box source above (SHA-256
`66e5916955cf4e7b0c2e9bd94675acd59eca5735fc30b00062ce0061f97a8a6c`).
Each row is pattern index, 48-bit ECC remainder and 16-bit CRC remainder.
The six 512-byte patterns are 00h, FFh, 55h, AAh, byte index modulo 256,
and `((index*73+19) XOR (index>>1)) modulo 256`. The native test compares
hardware-generated bytes against these fixed external results. It also
injects bursts at data, byte and check-field boundaries; correction changes
the controller's transfer buffer while retaining damaged external media.

Formal checks cover bounded controller safety (32 clocks) and five host
handshakes. They do not prove the complete ECC algorithm or whole-machine
behavior. Native tests exercise the longer data, correction and format paths.
