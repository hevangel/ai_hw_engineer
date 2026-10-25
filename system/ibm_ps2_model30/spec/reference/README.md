# Model 30 reference manifest

Primary references:

- IBM, *Personal System/2 Model 30 Technical Reference*, first edition,
  January 1987, [shared PDF scan](../../../../references/model30tr.pdf), [searchable text extraction](model30tr.txt), and [IBM archive](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf).
  Printed pages 1-6..1-24 define planar bus/refresh/interrupt/memory controls;
  1-44..1-78 define MCGA including font self-load; 1-80..1-83 define the
  Model 30 floppy diagnostic, DOR, DIR and CCR registers. Section 4 covers
  the Model M scan-code/command interface.
- IBM, [1989 sales advisor](https://bitsavers.org/pdf/ibm/pc/ps2/G320-9781-00_PS2_and_Printers_Sales_Advisor_198905.pdf),
  original Model 30-002 configuration.
- Original revision 2 ROM socket dumps, 61X8940/61X8939, February 5, 1987,
  [preserved by Ardent Tool](https://ardent-tool.com/firmware/system.html).
  The unchanged reset vector, POST register tests and BIOS routines are
  executable independent authorities for integration behavior.
- Original IBM 720 KiB [Model 30 Starter Disk](https://www.ibmfiles.com/ibmfiles/ps2/hamilton/30start.zip).
- Original PC DOS 3.30 [720 KiB disk 1](https://github.com/jeffpar/pcjs-diskettes/blob/cd3433748b09837a4c60ca7066f3642772b2d711/pcx86/sys/dos/ibm/3.30/PCDOS330-720K-DISK1.json).

The preparation script pins archive SHA-256 hashes and the PCjs Git blob,
validates original checksums, and writes an output manifest under ignored
`work/reference/`. The manual PDF scan is stored centrally under `references/`; its clean text extraction remains here. No ROM, font, OS image, or third-party firmware bytes are committed here. Firmware bytes are not patched.

Independent implementation references, pinned to 86Box revision
`ceb009f17daeecbb81e1ddf26ad63beda9300afe`:

- [Model 25/30 planar](https://github.com/86Box/86Box/blob/ceb009f17daeecbb81e1ddf26ad63beda9300afe/src/machine/m_ps2_isa.c)
- [Keyboard/pointing gate array](https://github.com/86Box/86Box/blob/ceb009f17daeecbb81e1ddf26ad63beda9300afe/src/device/kbc_ps2_m25.c)
- [MCGA registers and font organization](https://github.com/86Box/86Box/blob/ceb009f17daeecbb81e1ddf26ad63beda9300afe/src/video/vid_mcga.c)
- [MM58167 and Model 30 clock mapping](https://github.com/86Box/86Box/blob/ceb009f17daeecbb81e1ddf26ad63beda9300afe/src/device/isartc.c)
- [DMA page map](https://github.com/86Box/86Box/blob/ceb009f17daeecbb81e1ddf26ad63beda9300afe/src/dma.c)
- [Model 30 floppy registers](https://github.com/86Box/86Box/blob/ceb009f17daeecbb81e1ddf26ad63beda9300afe/src/floppy/fdc.c)

These are behavioral cross-checks, not copied implementation code. Where the
January manual disagrees with the February ROM (DMA pages), the discrepancy
is retained explicitly in the [assumption ledger](../spec.md).


The integrated fixed disk uses the independently documented IBM DBA
protocol, with the original Model 30 geometry, IRQ5 and DMA3. Sources and
fixed ECC/CRC vector provenance are recorded in the
[fixed-disk specification](../hard_disk.md). No drive MCU firmware or
unverified discrete controller chip identity is substituted for that contract.

## Additional application regression

The unchanged EDLIN.COM and BASICA.COM bytes come from the pinned PC DOS
3.30 disk above. `scripts/test_real_software.py` verifies their individual
SHA-256 hashes before booting a private copy of a DOS-created hard disk.
Its own `tb/software/primes.bas` is a new test workload executed by the
original interpreter, rather than a claimed historical BASIC program.

IBM's [DOS Version 3.30 Reference, April 1987](https://www.minuszerodegrees.net/manuals/IBM/IBM%20DOS%20Version%203.30%20-%20Reference%20-%20First%20Edition%20APR87.pdf),
printed page 8-19, specifies EDLIN's exact CR/LF/1Ah ending and original-file
.BAK rename. Microsoft's pinned [MS-DOS 2.0 EDLIN source](https://github.com/microsoft/MS-DOS/blob/2d04cacc5322951f187bb17e017c12920ac8ebe2/v2.0/source/EDLIN.ASM)
independently documents INSERT/ENDINS handling of a leading Ctrl-Z. The
regression executes the original 3.30 binary, rather than reconstructing
that application from the older source.
