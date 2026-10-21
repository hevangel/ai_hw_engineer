// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x671.md.
// =============================================================================
// ttl_74x671 - 4-bit universal shift register/latch with 3-state outputs
//
// Original part number : 74x671 (SN74LS671)
// Datasheet reference  : TI SN54LS671/672 (D2638)
//
// Function
// --------
// A 4-bit universal shift register (like '194A) plus a 4-bit storage register
// (like '175) multiplexed to a 3-state output stage (like '258).
//
//   Shift register (posedge srck), direct (asynchronous) clear via srclr_n; mode = {s1,s0}:
//     00 hold;  01 shift right (QA->QD, ser_r in at QA);
//     10 shift left (QD->QA, ser_l in at QD);  11 parallel load from d
//   Storage register (posedge rck): captures the shift-register outputs.
//   Output: r_s selects register/storage (1) or shift register (0); g_n
//     (active low) enables the 3-state outputs (high-Z modeled as 0).
//   casc: cascade output, always driven (even when outputs are high-Z) -
//     presents QA in shift-left mode, QD otherwise.
//
// d/q bit 0 = A / QA (LSB).
//
// FPGA notes
// ----------
// Two clocks (srck, rck). 3-state outputs modeled as muxed 0; casc never
// three-stated.
//
// Pin mapping (20-pin): SER R=1, SRCK=2, A=3, B=4, C=5, D=6, SER L=7, /SRCLR=8,
// RCK=9, GND=10, R/S=11, /G=12, S1=13, S0=14, QD=15, QC=16, QB=17, QA=18,
// CASC=19, Vcc=20.
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z on QA-QD (modeled as driven 0).
// =============================================================================

module ttl_74x671 (
    input  logic       ser_r,    // serial input for shift-right
    input  logic       srck,     // shift-register clock (posedge)
    input  logic [3:0] d,        // parallel data (d[0]=A .. d[3]=D)
    input  logic       ser_l,    // serial input for shift-left
    input  logic       srclr_n,  // shift-register clear, active low (direct (asynchronous) clear)
    input  logic       rck,      // storage-register clock (posedge)
    input  logic       r_s,      // R/S: 1 = storage register, 0 = shift register
    input  logic       g_n,      // output control, active low (3-state)
    input  logic       s0,
    input  logic       s1,
    output logic [3:0] q,        // 3-state outputs (q[0]=QA .. q[3]=QD)
    output logic       casc      // cascade output (always driven)
);
    logic [3:0] sr, str;

    always_ff @(posedge srck or negedge srclr_n) begin
        if (!srclr_n) sr <= 4'd0;
        else unique case ({s1, s0})
            2'b00: ;                            // hold
            2'b01: sr <= {sr[2:0], ser_r};      // shift right (QA -> QD)
            2'b10: sr <= {ser_l, sr[3:1]};      // shift left  (QD -> QA)
            2'b11: sr <= d;                       // parallel load
        endcase
    end

    always_ff @(posedge rck) str <= sr;

    assign casc = (s1 && !s0) ? sr[0] : sr[3];    // shift-left: QA; else QD
    assign q    = g_n ? 4'd0 : (r_s ? str : sr);
endmodule
