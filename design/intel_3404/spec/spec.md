# Intel 3404 specification

Primary contract: the combined [Intel 3205/3404 data sheet](../../../references/intel_3205_3404_datasheet.pdf)
("3404 High Speed 6-Bit Latch", catalog pages 2-35/2-38). The [November
1973 MCS-8 Users Manual](../../../references/intel_mcs8_users_manual_nov1973.pdf)
(scan page 33) shows the SIM8-01 using 3404s to latch the 8008's
time-multiplexed address bytes and the INP-instruction flag output. The
reconstruction implements the documented digital function without
electrical timing (12 ns data-to-output, 12 ns setup, 8 ns hold, 15 ns
minimum write pulse are not modeled) and without the physical 16-pin
interface.

## Device function (datasheet)

"The Intel 3404 contains six high speed latches organized as independent
4-bit and 2-bit latches. They are designed for use as memory data
registers, address registers, or other storage elements. The latches act
as high speed inverters when the 'Write' input is 'low'."

- Six stages, each output the complement of its stored data bit.
- Two write enables, one per section. While a section's write enable is
  low the section is transparent (outputs follow inverted inputs); the
  low-to-high transition stores, and a high enable holds. This follows
  the sheet's A.C. test waveform, which references tSETUP (data stable
  before the rising edge of write enable) and tHOLD (data stable after
  it).
- The two sections are fully independent.

## Interface

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | Reconstruction sampling clock (artifact, see A3) |
| `rst_n` | input | 1 | Active-low synchronous reset (artifact, see A3) |
| `d_i[3:0]` | input | 4 | Data inputs, 4-bit section |
| `d_i[5:4]` | input | 2 | Data inputs, 2-bit section |
| `w4_n_i` | input | 1 | Write enable, 4-bit section, active low (physical pin 7) |
| `w2_n_i` | input | 1 | Write enable, 2-bit section, active low (physical pin 15) |
| `q_n_o[3:0]` | output | 4 | Inverted outputs, 4-bit section |
| `q_n_o[5:4]` | output | 2 | Inverted outputs, 2-bit section |

The physical DIP-16 orders the cell pairs down the left side (pins 1-6,
write pin 7) and the right side (pins 9-14, write pin 15); the logical
bit order within a section is a modeling choice, not a sourced fact
(see A1).

## MCS-8 system context

The SIM8-01 stores the 8008's lower address byte (state T1) and higher
address byte plus CC0/CC1 control bits (state T2) in 3404 latches and
"provided to all memories"; the two highest-order bits are decoded for
control. Under the INP instruction the CPU's flag flip-flops are sent out
at state T4 and stored in a single 3404 (package A43) — the four flags
fit the 4-bit section.

## Assumption ledger

- **A1 (section bit mapping)**: logical bits `[3:0]` form the 4-bit latch
  on write enable `w4_n_i` (pin 7); bits `[5:4]` form the 2-bit latch on
  `w2_n_i` (pin 15). Sourced: the datasheet's "independent 4-bit and
  2-bit latches" text, corroborated by its D.C. table input-load figures
  (write pin 7: −1.0 mA; write pin 15: −0.5 mA — the heavier load is
  consistent with four gated inputs versus two). The stage order within
  each section is not modeled. ASSUMPTION comment present in the RTL.
- **A2 (transparent-while-low, latch-on-rising-edge)**: both sections
  behave per the sheet text ("inverters when the Write input is low") and
  the A.C. test waveform (setup/hold around the rising edge). ASSUMPTION
  comment present in the RTL.
- **A3 (synchronous reconstruction artifacts)**: the physical part has no
  clock and no reset; storage is indeterminate at power-up. The model
  samples the transparent state at rising clock edges and reset clears
  the stored bits (outputs high) deterministically. This mirrors the
  8008 core's documented deviation from the multiplexed electrical
  interface. ASSUMPTION comment present in the RTL.
- **A4 (usage mapping, context only)**: which SIM8-01 bus lines feed
  which 3404 stages is not modeled; only the latch function is
  reconstructed.

No other undocumented behavior is assumed; both write enables never
interact by construction and by proof.
