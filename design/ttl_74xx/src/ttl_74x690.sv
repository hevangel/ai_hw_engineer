// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x690.md.
// =============================================================================
// ttl_74x690 - 4-bit decimal counter/register/multiplexer, asynchronous clear
//
// Original part number : 74x690 (SN74LS690)
// Datasheet reference  : TI SN54LS690-693 (D2423)
//
// Function
// --------
// A 4-bit decade synchronous counter feeds both the counter output and a
// snapshot register; an output multiplexer (R/C) selects which appears on the
// 3-state outputs.
//
//   Counter (clk cck):
//     - asynchronous clear via cclr_n (active low)
//     - synchronous parallel load from d when load_n low (on cck edge)
//     - counts up when enp & ent; decade count wraps 9 -> 0
//     - rco = ent & (count == 9)        (ripple carry, for cascading)
//   Register (clk rck): captures the counter value on the rising edge of rck;
//     asynchronous clear via rclr_n (active low).
//   Output:
//     - r_c selects: 0 = counter, 1 = register
//     - g_n (active low) enables the 3-state outputs; high-Z modeled as 0.
//
// Data/outputs are vectors with bit 0 = A / QA (LSB), matching datasheet
// pins A,B,C,D and QA,QB,QC,QD.
//
// FPGA notes
// ----------
// Two independent clock domains (cck, rck) as on the real device. 3-state
// output modeled as muxed 0 per library convention.
//
// Pin mapping (20-pin): cclr_n=1, cck=2, A..D=3..6, enp=7, rclr_n=8, rck=9,
// GND=10, R/C=11, /G=12, /LOAD=13, ent=14, QD..QA=15..18, rco=19, Vcc=20.
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z (modeled as driven 0); electrical drive/timing.
// =============================================================================

module ttl_74x690 (
    input  logic       cck,      // counter clock (posedge)
    input  logic       cclr_n,   // counter clear, active low (asynchronous clear)
    input  logic       load_n,   // synchronous parallel load, active low
    input  logic       enp,      // count enable P
    input  logic       ent,      // count enable T
    input  logic [3:0] d,        // parallel data (d[0]=A .. d[3]=D)
    input  logic       rck,      // register clock (posedge)
    input  logic       rclr_n,   // register clear, active low (asynchronous)
    input  logic       r_c,      // output select: 0=counter, 1=register
    input  logic       g_n,      // output enable, active low (3-state)
    output logic [3:0] q,        // 3-state outputs (q[0]=QA .. q[3]=QD)
    output logic       rco       // ripple carry out
);

    logic [3:0] cnt;             // counter
    logic [3:0] rreg;            // snapshot register

    always_ff @(posedge cck or negedge cclr_n) begin
        if (!cclr_n)         cnt <= 4'd0;
        else if (!load_n)    cnt <= d;
        else if (enp && ent) cnt <= (cnt == 4'd9) ? 4'd0 : cnt + 4'd1;
    end

    always_ff @(posedge rck or negedge rclr_n) begin
        if (!rclr_n) rreg <= 4'd0;
        else         rreg <= cnt;
    end

    assign rco = ent && (cnt == 4'd9);
    assign q   = g_n ? 4'd0 : (r_c ? rreg : cnt);

endmodule
