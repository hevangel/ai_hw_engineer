# IBM EGA dropped attribute-controller writes to port 3C1

Date: 2026-11-16. External oracle: the unchanged IBM EGA BIOS (ROM 6277356,
9/13/84) running on the 80286 in the IBM PC AT 5170 system model.

## Failure

The EGA POST failed its dot test with BL = 10h (ERR_BEEP at C000:044E).
The I/O trace showed the attribute controller's index/data flip-flop out of
step: the BIOS wrote 3C0 = 0Fh, 3C1 = 3Fh, 3C0 = 32h, 3C1 = 0Fh, but
`ega_io_decode.sv` decoded only `lo == C0h`. The 3C1 writes were dropped, so
the flip-flop took 0Fh and 32h as an address and a data byte, the palette
address source bit stayed 0 and the screen was forced to the overscan
colour, so Input Status 1 bits 5-4 never toggled. With
`io_attr = u16 && (lo[7:1] == 7'h60)` the whole EGA POST passes on the AT
(sync timing, dot test, 256 KB memory test with INFO = 60h, mode 3 set,
correct 640x350 picture).

## Root cause

The BIOS's `OUT_DX` helper (C000:0D15: `XCHG AH,AL; OUT DX,AL; INC DX;
XCHG AH,AL; OUT DX,AL`) writes the index to DX and the data to DX+1. The
POST dot test calls it with DX = 3C0h (C000:0403-0416, listing lines
1307-1318), so the card must accept attribute writes at 3C1. The technical
reference's register section (p.56) names only 3C0, and the decode PROM
U34's contents are not printed. Assumption E3 read "decodes exactly the TR
ports", taken from the register text alone.

## Why the suite did not catch it

- The model and the RTL shared E3, so lockstep could not disagree, and the
  directed decode test even asserted that a 3C1 read is undecoded without
  checking 3C1 writes.
- The random generator did write 3C1, but both sides treated it as
  undecoded, so it only added coverage of "undecoded writes".
- The BIOS replay (`bios_replay.py`) replayed SET_REGS, which writes the
  attribute controller with two `OUT DX,AL` to 3C0 (C000:0E09), and skipped
  the POST self tests. It never used the BIOS's own port sequence for the
  OUT_DX attribute writes, so the one BIOS path that needs 3C1 was not run.
- The listing was searched for register values and mode-set sequences, not
  for every port each helper can reach.

## Fix and re-verification

- `ega_io_decode.sv` and `ega_model.py` accept attribute writes at 3C0 and
  3C1 (reads of 3C1 stay undecoded). E3, the port table and the register
  map in the spec cite the BIOS evidence.
- New directed test `bios_dot_test_attribute_writes`: the dot test's exact
  sequence (status read; 3C0 = 0Fh, 3C1 = 3Fh; 3C0 = 32h, 3C1 = 0Fh, 1Fh,
  2Fh) with literal expectations for palette 0Fh, Color Plane Enable,
  attribute index and flip-flop, and Input Status 1 = F4h during display and
  C5h in blanking for each video-status mux setting.
- Coverage gate requires `attr_write_3c1`; mutant m15 restores the old
  decode and must be killed.
- `run_all.sh` rerun from a clean work directory (see the design report).

Every OUT_DX call site in the ROM was listed by a byte scan for
`CALL 0D15h`: DX is 3C4 (to 3C5), 3CE (to 3CF), the CRTC base 3B4/3D4 (to
3x5) or 3C0 (to 3C1, six POST call sites at C000:0409-0580). 3C1 was the
only DX+1 port the decode did not accept. MAME (`ega.cpp`) also handles only
offset 0 of 3C0 for attribute writes; 86Box accepts 3C0 and 3C1.

## Prevention

For every BIOS-driven card or chip, list each port the firmware's I/O
helpers can reach (helpers that write DX and DX+1, or loop over a port
range) by scanning all call sites, and check each against the decode before
sign-off. A firmware replay must include the self-test code paths, not only
the mode-set paths, or state which helper/port combinations it leaves out.
