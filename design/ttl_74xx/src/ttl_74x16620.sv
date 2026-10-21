// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16620.md.
// ttl_74x16620 - 16-bit bus transceiver (= 74x245 widened).
module ttl_74x16620 (
    input  logic        oe_n, dir,
    input  logic [15:0] a_in, b_in,
    output logic [15:0] a_out, b_out,
    output logic        a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 16'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 16'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
