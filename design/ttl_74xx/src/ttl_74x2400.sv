// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2400.md.
// =============================================================================
// ttl_74x2400 - Dual 4-bit inverting buffer / 8-bit input port, 3-state
//
// Original part number : 74x2400 (74THC2400, iC-Haus iC-NH)
// Datasheet reference  : iC-Haus iC-NH "8-Bit Input Port (74THC2400)"
//
// Function
// --------
// Eight inverting buffers divided into two 4-bit nibbles, each nibble with its
// own active-high output-disable enable (a high level on the enable switches
// that nibble's outputs to the high-impedance state):
//
//   y1 = ng1 ? Z : ~a1      // nibble 1 (1A1..1A4 -> 1Y1..1Y4), enable 1NG
//   y2 = ng2 ? Z : ~a2      // nibble 2 (2A1..2A4 -> 2Y1..2Y4), enable 2NG
//
// High-Z is modeled as a driven 0 per library convention.
//
// FPGA notes
// ----------
// Pure combinational. 3-state modeled as muxed 0.
//
// Pin mapping (20-pin): 1NG=1, 1A1=2, 2Y4=3, 1A2=4, 2Y3=5, 1A3=6, 2Y2=7,
// 1A4=8, 2Y1=9, GND=10, 2A1=11, 1Y4=12, 2A2=13, 1Y3=14, 2A3=15, 1Y2=16,
// 2A4=17, 1Y1=18, 2NG=19, Vcc=20.
//
// Unsupported physical behavior
// -----------------------------
// Schmitt-trigger input hysteresis is not modeled (inputs are ideal logic
// levels). True three-state high-Z is modeled as a driven 0.
// =============================================================================

module ttl_74x2400 (
    input  logic [3:0] a1,       // nibble-1 inputs 1A1..1A4
    input  logic [3:0] a2,       // nibble-2 inputs 2A1..2A4
    input  logic       ng1,      // nibble-1 enable 1NG (high = high-Z)
    input  logic       ng2,      // nibble-2 enable 2NG (high = high-Z)
    output logic [3:0] y1,       // nibble-1 outputs 1Y1..1Y4
    output logic [3:0] y2        // nibble-2 outputs 2Y1..2Y4
);
    assign y1 = ng1 ? 4'b0000 : ~a1;
    assign y2 = ng2 ? 4'b0000 : ~a2;
endmodule
