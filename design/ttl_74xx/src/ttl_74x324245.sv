// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x324245.md.
// ttl_74x324245 - 32-bit dual supply bus transceiver (= 74x245 widened).
// Voltage translation between Va/Vb supplies is not modeled.
module ttl_74x324245 (
    input  logic        oe_n, dir,
    input  logic [31:0] a_in, b_in,
    output logic [31:0] a_out, b_out,
    output logic        a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 32'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 32'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
