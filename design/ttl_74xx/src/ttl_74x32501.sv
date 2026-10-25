// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x32501.md.
// ttl_74x32501 - 36-bit universal bus transceiver.
// 36-bit version of 74x245.
module ttl_74x32501 (
    input  logic        oe_n, dir,
    input  logic [35:0] a_in, b_in,
    output logic [35:0] a_out, b_out,
    output logic        a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 36'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 36'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
