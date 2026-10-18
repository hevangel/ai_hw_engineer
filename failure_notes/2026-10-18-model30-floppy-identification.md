# Model 30 stock floppy identified as high density

## External failure

Unmodified PC DOS 3.30 FORMAT B: selected 18 sectors per head and reported
track zero unusable on the physical 720K medium. The FDC/DMA unit test passed
because it explicitly supplied nine-sector commands instead of asking the
original BIOS to identify the drive.

## Root cause and evidence

The keyboard/pointing gate-array register at 6Ah returned zero in bit 0.
The original 02/05/87 IBM ROM at F000:0F0E tests that input, setting BDA
40:8F bit 1 (or bit 5 for B) when low. INT 13h AH=08 then returns type 4,
causing DOS to select 18 sectors/500 kbit/s. The stock Model 30 is a 720K,
type-3 machine per the [January 1987 IBM Technical Reference](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf).
The precise input wiring is undocumented in this scan; its required stock
value is explicitly tracked as assumption A12, derived from the original
ROM and validated against original software.

The host's decoded medium also ignored CCR rate selection and allowed an
out-of-range sector ID to spill into the adjacent head of the flat image.
These errors hid the firmware/controller disagreement during bring-up.

## Repair and prevention

The stock-drive identification input reads high. Physical 720K headers and
data require CCR bit 1 (250 kbit/s); spindle index still rotates at the
wrong rate. Format writes reject out-of-geometry IDs. A CPU board assertion
checks the identification input, the disk fixture selects the documented
rate, and the historical suite requires unchanged FORMAT to format all
80 cylinders and both heads and verifies its FAT12 bytes independently.
Custom floppy ID layouts are outside the canonical flat-media boundary.

The repaired board and CPU/FDC/DMA fixtures pass. Original FORMAT completes
all 160 tracks at 1,183,000,000 cumulative CPU clocks and returns the expected
730,112 usable bytes. Its final result, physical writes and subsequent FAT12
file comparison are required by the historical regression.
