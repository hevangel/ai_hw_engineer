# Model 30 planar integration gaps exposed by original POST

The unchanged February 1987 Model 30 BIOS found integration behavior that
standalone peripheral verification did not exercise.

## 8 MHz CPU / 4 MHz DMA register crossing

The first board connected a single CPU-clock-wide I/O strobe directly to the
4 MHz 8237. Depending on phase, a native 8086 cycle could complete before the
DMA clock sampled it. POST's register test at F000:012C then halted through
the ROM's early failure path. Both devices' individual protocols were
correct; the board had no clock-domain completion handshake.

`model30_dma_bridge` now latches a request, holds the 8237 interface until
its own clock consumes it, captures read data, and acknowledges completion
before the CPU leaves Tw. Word I/O uses two actual DMA register accesses.
Original POST validates all channel register bytes; the board fixture checks
single-byte and word transactions through the native CPU.

## Planar status registers

The 5150's diskette register subset is insufficient for the Model 30. Original
POST explicitly checks 3F1h drive selects and the latched step flag in 3F0h,
then uses the Model 30's inverted disk-change indication and CCR readback.
Omitting them produced `602-Diskette Drive/System Board Error` for both
drives. The initial UART register subset also lacked its interrupt path and
produced `1101-Serial Port Error`.

The board now models the IBM-defined floppy diagnostic registers and the
serial loopback/interrupt-identification path. Authorities are IBM's
[Technical Reference](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf),
printed pp.1-80..1-83 and 1-110..1-118, the unchanged ROM tests, and the
independent 86Box Model 30 implementation linked in the system reference
manifest. The board fixture exercises CCR/DIR/drive-select status, UART
loopback and RX interrupt identification.

## Prevention and validation

Test the system's actual clock ratios and all manufacturer POST-visible
registers before treating a reused peripheral as integrated. Keep exact-PC
board fixtures and unchanged POST/DOS runs in the aggregate flow. The system
report records the actual results; an implemented repair alone is not
evidence that full POST or DOS boot passed.

## Keyboard defaults after POST

Original DOS reached its date prompt, but the front panel emitted scan set
2 bytes because the modeled F5 command had reverted the keyboard from
set 1. The BIOS LED routine at F000:E294 sends F5, ED, the LED parameter
and F4 without reissuing F0/1. The Model 30 has no 8042 translator. IBM TR
p.4-4 defines scan set 1 after POR; independent 86Box `kbc_ps2_m25.c`
explicitly preserves the selected set through default commands.

The model now starts/reset-completes in set 1, preserves selection across
F5/F6, and enables scanning on F6. The directed CPU fixture executes the
actual LED command sequence, queries the selected set, and checks external
key-ready after F6. The historical regression requires set 1 and types the
DOS date, commands and BASIC expressions through the same receive IRQs.
No host scan-code override is used to mask an incorrect hardware state.
