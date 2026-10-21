// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x32973.md.
// ttl_74x32973 - 16-bit bus transceiver and 16-bit transparent D-type latch.
// Combines 16-bit 245-style transceiver + 16-bit 573-style latch.
module ttl_74x32973 (
    input  logic        oe_n, dir,
    input  logic [15:0] a_in, b_in,
    output logic [15:0] a_out, b_out,
    output logic        a_hiz, b_hiz,
    input  logic        le, latch_oe_n,
    input  logic [15:0] l_d,
    output logic [15:0] l_q,
    output logic        l_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 16'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 16'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
    logic [15:0] latch_q;
    always_latch if (le) latch_q = l_d;
    assign l_q   = latch_oe_n ? 16'b0 : latch_q;
    assign l_hiz = latch_oe_n;
endmodule
