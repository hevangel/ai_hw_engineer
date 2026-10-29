// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16973.md.
// ttl_74x16973 - 8-bit bus transceiver and transparent D-type latch.
// 16-bit-class part: combines an 8-bit bidirectional bus transceiver
// and an 8-bit transparent latch into one package.
module ttl_74x16973 (
    // Transceiver section (74x245-style)
    input  logic       oe_n, dir,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz,
    // Latch section (74x573-style)
    input  logic       le, latch_oe_n,
    input  logic [7:0] l_d,
    output logic [7:0] l_q,
    output logic       l_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 8'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 8'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;

    logic [7:0] latch_q;
    always_latch if (le) latch_q = l_d;
    assign l_q   = latch_oe_n ? 8'b0 : latch_q;
    assign l_hiz = latch_oe_n;
endmodule
