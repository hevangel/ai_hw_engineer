# Intel 3205 specification

Primary contract: the combined [Intel 3205/3404 data sheet](../../../references/intel_3205_3404_datasheet.pdf)
("3205 High Speed 1 Out of 8 Binary Decoder", catalog pages 2-35/2-37). The
[November 1973 MCS-8 Users Manual](../../../references/intel_mcs8_users_manual_nov1973.pdf)
(scan page 32) prints the same truth table and shows the SIM8-01 using the
3205 for 8008 state-line decoding and memory chip-select generation. The
reconstruction implements the documented digital function without
electrical propagation delays (18 ns address/enable-to-output is not
modeled) and without the physical 16-pin interface.

## Interface

| Port | Direction | Width | Physical pin | Description |
|------|-----------|-------|--------------|-------------|
| `a_i` | input | 3 | A0/A1/A2 (pins 1-3) | Binary select address |
| `e1_n_i` | input | 1 | E1̅ (pin 4) | Chip enable, active low |
| `e2_n_i` | input | 1 | E2̅ (pin 5) | Chip enable, active low |
| `e3_i` | input | 1 | E3 (pin 6) | Chip enable, active high |
| `out_n_o` | output | 8 | O̅7..O̅0 (pins 7, 9-15) | One-of-eight selected output, active low |

## Function

Enable requires `e1_n_i == 0`, `e2_n_i == 0` and `e3_i == 1` simultaneously.

- Enabled: output `out_n_o[a_i]` is low and every other output is high
  (one-of-eight active low).
- Disabled: all eight outputs are high.

All 2^6 = 64 input combinations are defined by the datasheet truth table;
no state, no clock, no reset, no undocumented encodings.

## MCS-8 system context

The SIM8-01 module decodes the 8008 state lines S0-S2 with a 3205 (package
A44) gated with clock and SYNC, and uses further 3205s for memory chip
selects. The datasheet notes that 3205 decoders cascade such that each
decoder can drive eight others for arbitrary memory expansion; the
testbench verifies that two-level arrangement functionally.

## Assumptions

None. The device is fully specified by the truth table; the reconstruction
covers all input combinations.
