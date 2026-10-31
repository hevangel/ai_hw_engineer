// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x9245.md.
// ttl_74x9245 - 9-bit bidirectional transceiver, non-inverting.
module ttl_74x9245 (
    input  logic       oe_n, dir,
    input  logic [8:0] a_in, b_in,
    output logic [8:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 9'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 9'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
