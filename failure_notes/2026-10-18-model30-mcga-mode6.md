# Model 30 MCGA mode 6 incorrectly classified as text

## External failure

Original BASICA 3.30 SCREEN 2 called the original IBM BIOS successfully,
but the platform still reported text mode and rendered bitmap bytes as
characters. The BIOS had written 18h to the CGA-compatible mode register.

## Root cause and authority

The graphics decoder required bit 1, copying a generic CGA assumption.
[IBM Model 30 Technical Reference](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf),
printed page 1-55, explicitly defines bit 4 as independently selecting
640x200 mode 6, while bit 1 selects the 320x200 modes. The pinned independent
86Box vid_mcga.c also tests the high-resolution bit before the graphics bit.
The old board fixture exercised native MCGA modes and omitted this valid
high-resolution-only combination, so it missed the integration defect.

## Repair and prevention

Either bit 4 or bit 1 selects compatible graphics when a native MCGA mode
is not selected. A literal CPU fixture writes the original BIOS value 18h
and requires calculated mode-status 34h: 640-wide, double-scanned graphics,
with the alpha bit clear. Calculated width follows the selected native mode;
mode 13h returns status 15h even when the preceding compatible high-resolution
bit remains set. The historical display suite runs original
BASICA SCREEN 2 and checks a rectangle in interleaved display memory.
Native modes 13h/11h are exercised through original DEBUG/BIOS calls with
exact pixel-framebuffer comparisons. BASICA's SCREEN 13 rejection is a
separate language limitation, not a hardware defect; see the independent
[BASICA/GW-BASIC reference](https://robhagemans.github.io/pcbasic/doc/2.0/).

Final verification results are recorded in the Model 30 report. Keep the
manufacturer's peripheral-specific register definitions as the authority,
rather than assuming a compatible interface has identical mode selection.
