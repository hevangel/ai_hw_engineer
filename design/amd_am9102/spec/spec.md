# Am9102 functional specification

Authority: AMD's [1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf),
printed pages 5-61 to 5-66, one-based PDF pages 498-503. Page 5-64 explicitly
states that output follows input during selected writes; 5-65 defines standby.
The Am9102, Am9102A and Am9102B share this binary contract. Their guaranteed
650/500/400 ns cycle times are electrical grades, not different logic.

## Interface

1024 words of one bit; asynchronous read and level-sensitive write. No clock,
reset or known power-up state. All 10-bit addresses are legal.

| Port | Historical meaning |
|---|---|
| `a_i[9:0]` | A9-A0 address pins |
| `cs_n_i` | Active-low CS |
| `we_n_i` | Active-low WE |
| `din_i` | Data input |
| `dout_o` | Non-inverting data output, qualified by the flags below |
| `dout_oe_o` | Output driver enabled; false represents high impedance |
| `standby_i` | Supply-mode metadata, not a historical pin: retained low-voltage standby |
| `output_valid_o` | Mode validity metadata, not a historical pin |

At normal supply: CS HIGH disables output and prevents writing, irrespective
of WE. CS LOW/WE HIGH reads the addressed word. CS LOW/WE LOW writes the
addressed cell while the enable remains LOW, and output follows DIN. The
output is not inverted and is not disabled during a selected write. Arbitrary
address/data changes violating the datasheet's setup/hold times are excluded.

## Retained-power standby

Standby represents VCC held at the documented retention voltage (at least
1.6 V), not loss of power. Cells retain contents and are isolated from data
lines. No reads or writes are permitted. The external supply controller must
raise CS before entering standby, hold it HIGH throughout, and allow one
TCYCLE recovery interval after restoring normal supply before access.
The zero-delay core has no timer: the caller owns those delays.

For legal standby, CS HIGH, output is disabled. CS LOW in standby does not
have a guaranteed output level in the source; `output_valid_o=0` explicitly
marks that invalid mode. The implementation chooses OE=0/data=X as a
representative there, without claiming the physical chip does so. Storage
isolation remains modeled. In every normal-supply mode and legal standby,
`output_valid_o=1`; this does not imply that an unwritten word is known.
`dout_o` is X whenever OE is false, so consumers must qualify data with OE.

## Implementation boundary

Binary, zero-delay synthesizable reconstruction, with actual asynchronous
storage latches. Split data/OE supports a physical tri-state I/O wrapper or a
shared-bus functional wrapper. No implicit reset, FPGA block RAM replacement,
refresh requirement, or invented standby command register. Voltage/current,
retention failure below minimum voltage, delays and metastability require an
electrical model and are outside this contract. All defined binary behavior
above is stated by the manufacturer; there are no additional semantic
assumptions requiring an assumption-ledger entry.
