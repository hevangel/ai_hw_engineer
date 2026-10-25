// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x696.md.
// =============================================================================
// ttl_74x696 - 4-bit decimal up/down counter/register/multiplexer, asynchronous clear
//
// Original part number : 74x696 (SN74LS696)
// Datasheet reference  : TI SN54LS696-699 (D2424)
//
// Function
// --------
// A 4-bit decade synchronous UP/DOWN counter feeds both the counter output and
// a snapshot register; an output multiplexer (R/C) selects which appears on the
// 3-state outputs. (Up/down version of the '690-693; no register-clear pin.)
//
//   Counter (clk cck):
//     - asynchronous (direct) clear via cclr_n (active low)
//     - synchronous parallel load from d when load_n low (on cck edge)
//     - counts when enp & ent: u_d=1 up, u_d=0 down; decade wrap
//       (up: 9 -> 0, down: 0 -> 9)
//     - rco = ent & (terminal count in the active direction)
//   Register (clk rck): captures the counter value on the rising edge of rck.
//     There is no register clear on this part.
//   Output:
//     - r_c selects: 0 = counter, 1 = register
//     - g_n (active low) enables the 3-state outputs; high-Z modeled as 0.
//
// Data/outputs are vectors with bit 0 = A / QA (LSB).
//
// FPGA notes
// ----------
// Two independent clock domains (cck, rck). 3-state output modeled as muxed 0.
//
// Pin mapping (20-pin): U/D=1, cck=2, A..D=3..6, enp=7, cclr_n=8, rck=9,
// GND=10, R/C=11, /G=12, /LOAD=13, ent=14, QD..QA=15..18, rco=19, Vcc=20.
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z (modeled as driven 0); electrical drive/timing.
// =============================================================================

module ttl_74x696 (
    input  logic       cck,      // counter clock (posedge)
    input  logic       cclr_n,   // counter clear, active low (asynchronous (direct) clear)
    input  logic       load_n,   // synchronous parallel load, active low
    input  logic       u_d,      // direction: 1 = up, 0 = down
    input  logic       enp,      // count enable P
    input  logic       ent,      // count enable T
    input  logic [3:0] d,        // parallel data (d[0]=A .. d[3]=D)
    input  logic       rck,      // register clock (posedge)
    input  logic       r_c,      // output select: 0=counter, 1=register
    input  logic       g_n,      // output enable, active low (3-state)
    output logic [3:0] q,        // 3-state outputs (q[0]=QA .. q[3]=QD)
    output logic       rco       // ripple carry out
);

    logic [3:0] cnt;
    logic [3:0] rreg;

    always_ff @(posedge cck or negedge cclr_n) begin
        if (!cclr_n)         cnt <= 4'd0;
        else if (!load_n)    cnt <= d;
        else if (enp && ent) begin
            if (u_d) cnt <= (cnt == 4'd9) ? 4'd0        : cnt + 4'd1;  // up
            else     cnt <= (cnt == 4'd0)        ? 4'd9 : cnt - 4'd1;  // down
        end
    end

    always_ff @(posedge rck) rreg <= cnt;   // snapshot register (no clear)

    assign rco = ent && (u_d ? (cnt == 4'd9) : (cnt == 4'd0));
    assign q   = g_n ? 4'd0 : (r_c ? rreg : cnt);

endmodule
