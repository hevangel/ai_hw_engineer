// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x00 - Quad 2-input NAND gate
//
// Original part number : 74x00 (74LS00, 74HC00, 74AS00, 74F00, ...)
// Description          : Four independent 2-input NAND gates in a 14-pin DIP.
// Datasheet reference  : TI SN74LS00 (https://www.ti.com/lit/gpn/sn74ls00)
//
// FPGA notes
// ----------
//   y[i] = ~(a[i] & b[i])
// Pure combinational. No clock, no reset, no enable. Synthesizes to four
// LUT2s on any modern FPGA (or one LUT4 per pair if optimization merges).
//
// Pin mapping (DIP-14):
//   pin 1  = a[0]    pin 14 = Vcc
//   pin 2  = b[0]    pin 13 = b[3]
//   pin 3  = y[0]    pin 12 = a[3]
//   pin 4  = a[1]    pin 11 = y[3]
//   pin 5  = b[1]    pin 10 = b[2]
//   pin 6  = y[1]    pin 9  = a[2]
//   pin 7  = GND     pin 8  = y[2]
//
// Unsupported physical behavior
// -----------------------------
// None. The 74x00 is a basic logic gate with no analog, tri-state, or
// open-collector behavior.
// =============================================================================

module ttl_74x00 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);

    assign y = ~(a & b);

endmodule
