// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x867.md.
// =============================================================================
// ttl_74x867 - Synchronous 8-bit up/down counter
//
// Original part number : 74x867 (SN74ALS867A/SN74AS867)
// Datasheet reference  : TI SDAS115C
//
// Function
// --------
// Fully programmable 8-bit up/down counter with mode select, synchronous load,
// count enables, and a ripple-carry output for n-bit cascading.
//
//   S1 S0 | function
//    L  L | Clear   (asynchronous clear (S1,S0 = L,L clears immediately))
//    L  H | Count down  (when enp_n & ent_n both low)
//    H  L | Load D      (synchronous)
//    H  H | Count up    (when enp_n & ent_n both low)
//
//   rco_n (active low) pulses low at terminal count in the active direction
//   (0xFF counting up, 0x00 counting down) and is gated by ent_n:
//     rco_n = ent_n | ~( (up & q==8'hFF) | (down & q==8'h00) )
//
// Outputs are always driven (no output-enable pin). d[0]=A/QA is the LSB.
//
// FPGA notes
// ----------
// Posedge-clocked; asynchronous clear (S1,S0 = L,L clears immediately).
//
// Pin mapping (24-pin): S0=1, S1=2, A..H=3..10, /ENT=11, GND=12, /RCO=13,
// CLK=14, QH..QA=15..22, /ENP=23, Vcc=24.
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing.
// =============================================================================

module ttl_74x867 (
    input  logic       clk,
    input  logic       s0,
    input  logic       s1,
    input  logic       enp_n,    // count enable P, active low
    input  logic       ent_n,    // count enable T, active low
    input  logic [7:0] d,        // parallel data (d[0]=A .. d[7]=H)
    output logic [7:0] q,        // outputs (q[0]=QA .. q[7]=QH)
    output logic       rco_n     // ripple carry out, active low
);
    logic [7:0] cnt;
    logic clr_n;
    assign clr_n = s0 | s1;       // clear (S1=S0=L) -> clr_n=0

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) cnt <= 8'd0;                       // asynchronous clear
        else unique case ({s1, s0})
            2'b01: if (!enp_n && !ent_n) cnt <= cnt - 8'd1;  // count down
            2'b10: cnt <= d;                                 // load
            2'b11: if (!enp_n && !ent_n) cnt <= cnt + 8'd1;  // count up
            default: ;                                       // 2'b00 = clear (async)
        endcase
    end

    assign q = cnt;
    assign rco_n = ent_n |
        ~(((s1 && s0) && (cnt == 8'hFF)) || ((!s1 && s0) && (cnt == 8'h00)));
endmodule
