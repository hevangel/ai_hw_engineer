// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1604.md.
// =============================================================================
// ttl_74x1604 - Dual 8-bit transparent latch with output multiplexer
//
// Original part number : 74x1604 (74F1604)
// Datasheet reference  : Philips 74F1604 (Product specification, 1990)
//
// Function
// --------
// Stores 16-bit-wide data (an 8-bit A latch and an 8-bit B latch), with the
// latch outputs feeding eight 2-input multiplexers to give 8 outputs.
//
//   Both latches share one active-low latch enable le_n:
//     le_n = 0 : transparent (a_lat <= a, b_lat <= b)
//     le_n = 1 : latched (hold the value present before the L->H transition)
//   Output mux selected by sel_ab (SELECT A/B-bar):
//     sel_ab = 1 : Q = A latch
//     sel_ab = 0 : Q = B latch
//
// The mux selects between the LATCHED A and B values, so toggling sel_ab while
// latched changes the output between the two held words (datasheet Function
// Table note). No output enable / three-state.
//
// FPGA notes
// ----------
// Two transparent latches (always_latch) plus a combinational output mux.
//
// Pin mapping (28-pin): /LE=1, SELECT A/B=2, A0=3, B0=4, A1=5, B1=6, A2=7,
// B2=8, A3=9, B3=10, Q3=11, Q2=12, Q1=13, GND=14, Q=15(Q0), Q4=16, Q5=17,
// Q6=18, Q7=19, B7=20, A7=21, B6=22, A6=23, B5=24, A5=25, B4=26, A4=27, Vcc=28.
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing.
// =============================================================================

module ttl_74x1604 (
    input  logic [7:0] a,        // A0..A7 data inputs
    input  logic [7:0] b,        // B0..B7 data inputs
    input  logic       sel_ab,   // SELECT A/B-bar: 1 = A latch, 0 = B latch
    input  logic       le_n,     // latch enable, active low (transparent when low)
    output logic [7:0] q         // Q0..Q7
);
    logic [7:0] a_lat, b_lat;

    always_latch begin
        if (!le_n) begin
            a_lat = a;
            b_lat = b;
        end
    end

    assign q = sel_ab ? a_lat : b_lat;
endmodule
