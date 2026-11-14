# Am29334 digital specification

Primary contract: AMD 1988 *Am29C300/29300 Data Book*, "Am29334 Four-Port
Dual-Access Register File", Amendment 10, PDF 201–215 of
[the bitsavers scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf)
(page images visually inspected; SHA256 in `../references/README.md`).

64 words × 18 bits, fully asynchronous (no clock pin): two read ports
(YA/YB output latches), two write ports (DA/DB), four 6-bit addresses.

## Pin contract

| Pin | Contract |
| --- | --- |
| ARA/ARB5–0 | read addresses, active high |
| AWA/AWB5–0 | write addresses, active high |
| DA/DB17–0 | write data |
| WEAC/WEBC (active low) | common write enables; also select the on-chip address multiplexer: RAM address = AWA/AWB while low, ARA/ARB while high |
| WEAL/WEAH, WEBL/WEBH (active low) | per-byte write enables; low byte = bits 8:0, high byte = bits 17:9 |
| LEA/LEB | output latch enables: high = transparent (follows the RAM read of the multiplexed address), low = hold |
| OEA/OEB (active low) | three-state output enables |

## Behavior

- A write occurs whenever the common enable and the corresponding byte
  enable are low; one or both bytes merge into the selected word.
- Read during a write window of the same location returns the value being
  written (byte-merged), on the same port through the multiplexed address
  (datasheet page 3-79 transparency note and Figure 2).
- Writing one location from both sides in the same window is documented
  undefined but harmless.
- Output latches follow the RAM read while LE is high and hold the last
  defined read otherwise; OEA/OEB gate the pins.

## Assumption ledger

- ASSUMPTION: both-sides-write-same-cell-and-byte resolves with the A
  side winning that byte (B's write applies to every other cell and byte
  concurrently). The datasheet leaves the result undefined; the model
  chooses determinism.
- ASSUMPTION: cross-port visibility. The datasheet states the
  transparency for the writing port; the model implements a single
  storage array, so a concurrent read of the written location through
  the other port also observes the written value. The datasheet does not
  state cross-port read-during-write behavior.
- ASSUMPTION: uninitialized cells and partially written cells read as
  undefined data. The model holds real storage contents (simulation
  starts at zero), and verification masks value checks whenever the
  oracle's cell image is not fully defined.
- The part has no reset and no clock; power-up contents are outside the
  contract. Electrical timing (24 ns access) is not modeled.
- The 32×36 single-access configuration (datasheet Figure 4) is a board
  wiring pattern of two halves, not device behavior; not modeled.
