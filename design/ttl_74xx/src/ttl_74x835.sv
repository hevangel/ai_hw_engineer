// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x835.md.
// =============================================================================
// ttl_74x835 - 8-bit shift register with 2:1 mux-in, latched "B" inputs
//
// Original part number : 74x835 (74F835)
// Datasheet reference  : Philips 74F835 (Product specification, 1990)
//
// Function
// --------
// An 8-bit parallel/serial-in, serial-out shift register that combines a '373
// (transparent latch on the B inputs), two '157s (a per-bit 2:1 input mux), and
// a '166 (the 8-bit shift register). Designed for interleaved video bit
// shifting.
//
//   B latch:  transparent when le high, holds when le low      (b_lat <= db)
//   2:1 mux:  s_ab = 0 -> A inputs (da); s_ab = 1 -> latched B  (mux)
//   Shift register (rising edge of cp):
//     pe_n = 0 : parallel load the mux value      sr <= mux
//     pe_n = 1 : shift            DS -> Q0 ... -> Q7   sr <= {sr[6:0], ds}
//   Output: q7 = Q7 (serial out, the register MSB)
//
// Per the datasheet Function Table (operating modes: parallel load A,
// latch B, parallel load B from latch, parallel load B transparent, serial
// shift).
//
// FPGA notes
// ----------
// One transparent latch (the B latch) plus an 8-bit shift register. Serial-out
// only (Q0..Q6 are internal).
//
// Pin mapping (24-pin): PE=1, CP=2, D4A=3, D5A=4, D6A=5, D7A=6 (... A inputs),
// D0B..D7B on the B side, DS=15, SA/B=14, LE=13, Q7=11, Vcc=24, GND=12.
// da[n]=DnA, db[n]=DnB.
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing.
// =============================================================================

module ttl_74x835 (
    input  logic       pe_n,     // parallel enable, active low (0 = load, 1 = shift)
    input  logic       cp,       // clock (rising edge)
    input  logic       le,       // B-input latch enable (high = transparent)
    input  logic       s_ab,     // mux select: 0 = A (da), 1 = B (latched db)
    input  logic [7:0] da,       // A parallel inputs D0A..D7A
    input  logic [7:0] db,       // B parallel inputs D0B..D7B
    input  logic       ds,       // serial data input
    output logic       q7        // serial output (register MSB)
);
    logic [7:0] b_lat, sr, mux;

    always_latch if (le) b_lat = db;          // transparent B latch

    assign mux = s_ab ? b_lat : da;

    always_ff @(posedge cp) begin
        if (!pe_n) sr <= mux;                 // parallel load
        else       sr <= {sr[6:0], ds};       // shift: DS -> Q0 ... -> Q7
    end

    assign q7 = sr[7];
endmodule
