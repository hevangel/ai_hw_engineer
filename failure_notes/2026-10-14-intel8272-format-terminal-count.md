# 8272 format dropped the sector whose final ID byte carried TC

Date: 2026-10-14. Found while integrating the original IBM PC diskette adapter.

## Failure and cause

A new CPU/8237/FDC board regression formatted an eight-sector track using a
32-byte CHRN ID table. DMA asserted terminal count on the last N byte. The
controller returned a normal result but emitted only 3,584 filler bytes;
the final sector's 512-byte data field was missing.

The execution-wide TC abort condition included `FORMAT_ID` unconditionally.
It took priority over an accepted final ID write, so the controller skipped
both that byte and the transition to `FORMAT_DATA`.

## External authority and repair

Intel's [8272A datasheet](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf),
“FORMAT A TRACK,” defines four host ID requests per sector followed by the
controller-generated filler data field, and termination at the trailing
index. TC may abort a command, but the final accepted ID must not disappear.
The repair retains asynchronous TC abort between ID bytes while allowing an
accepted ID byte to execute. The TC latch then ends formatting after that
sector's data field.

## Why verification missed it

The chip's format test used DMA handshakes but completed by sector count without
TC. Its existing TC tests covered read/write data, not the final format ID.
Per-command testing missed this interaction between format and real DMA count.

## Regression and evidence

- Repeat the chip's nonsequential-ID format test with TC on the last N byte;
  check every filler byte and the trailing-index/result sequence.
- `system/ibm_pc/tb/disk.S` runs actual CPU I/O, the 8237, the FDC and the media
  responder. Assert exact final CS:IP, normal status, exactly 4,096 writes,
  all eight sectors' bytes, and no modification of unselected drive A.
- Before the fix the board test fails with `3584`; afterward it passes.

Artifacts: `system/ibm_pc/work/disk_test.log` and the chip simulation logs.

## Related escaped VERIFY defect

After formatting, original DOS calls BIOS disk verification. IBM's unchanged
`DISK_VERF` routine uses 8237 mode 42h and FDC READ DATA. Intel specifies that
DMA VERIFY leaves memory and I/O strobes inactive. The FDC model dropped DRQ
on DACK but retained a pending byte until RD, so the next byte caused overrun.
The prior chip test explicitly required RD for every DMA read and therefore
excluded the real manufacturer's software combination.

The model now consumes a DMA read byte when DACK completes if normal RD has
not already consumed it. This preserves byte stability during ordinary DMA.
The exact digital completion edge is explicitly assumption A8; no silicon
waveform equivalence is asserted. Tests check DACK-only byte service, TC and
normal results, plus 4,096 real 8237 VERIFY cycles with RAM unchanged. Sources
and the historical-software requirement are in the [assumption ledger](../design/intel_8272/spec/spec.md).
