# Am3101 functional specification

Original contract: AMD [1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf),
printed pages 6-11 to 6-16 (PDF pages 516-521). Description on 6-11 and
truth table/user note on 6-15 are authoritative. This is the original
Am3101, not the later Am3101A/Am27S02 datasheet on 6-17.

## Interface

64 bits organized as 16 words of four bits, fully decoded, asynchronous
read and level-sensitive write. There is no clock or reset pin. Contents
at power-up are unspecified until written. No implicit initialization.

| RTL port | Historical signal | Meaning |
|---|---|---|
| `a_i[3:0]` | A3-A0 | Four-bit address; all 16 words legal |
| `cs_n_i` | CS-bar | Active-low selection |
| `we_n_i` | W-bar | Active-low write enable |
| `d_i[3:0]` | D4-D1 | Data inputs, bit 0 maps to D1 |
| `q_n_o[3:0]` | O4-O1 (inverting) | Output pin logic level with pull-up |
| `output_valid_o` | Reconstruction metadata | Whether the datasheet defines output behavior in this control mode |

## Operation

Whenever CS and W are LOW, the addressed storage word tracks D. When the
write condition closes, its last settled data is retained. Writes are
level-sensitive, not triggered only by a W falling or rising edge. Address
and data must meet the original write-cycle setup/hold requirements.

| CS | W | Stored data | Output |
|---:|---:|---|---|
| 0 | 0 | Addressed word tracks D | Inverted D, per truth table |
| 0 | 1 | Retain | Inverted addressed memory word |
| 1 | 1 | Retain | All HIGH (open collectors released) |
| 1 | 0 | Retain | Unspecified; may follow inverted D |

The unspecified deselected-write row is essential: do not assume all outputs
are released solely because CS is HIGH. `q_n_o` is X in that row in the
four-state functional model and `output_valid_o` is LOW. Synthesis may
choose any representative value for X, so consumers must respect this mode
mask. In every other row `output_valid_o` is HIGH; this does not certify
that an unwritten memory word has known power-up data.

## Open-collector abstraction

`q_n_o=0` means sink LOW, `q_n_o=1` means release HIGH through an external
pull-up, not actively drive HIGH. To model a legal shared output bus, AND
the output levels of selected/read and deselected/read devices. The test
bench wires two chips this way and uses W HIGH on the inactive chip.
Use an FPGA I/O wrapper or board-level model for physical open-drain pins.

## Boundaries and assumptions

This is zero-delay binary storage/output behavior, including genuine
asynchronous write latches. It is not a synchronous SRAM substituted for
the chip. Electrical delay, loading, metastability and address/data changes
violating write timing are outside scope. No undocumented binary semantics
or deterministic power-up state are assumed; the manufacturer X row remains
explicitly unspecified rather than guessed.
