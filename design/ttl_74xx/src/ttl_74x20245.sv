// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x20245.md.
// ttl_74x20245 - 20-bit dual supply bus transceiver.
// 20-bit version of 74x245; "dual supply" denotes Va/Vb voltage translation
// that is not modeled here.
module ttl_74x20245 (
    input  logic        oe_n, dir,
    input  logic [19:0] a_in, b_in,
    output logic [19:0] a_out, b_out,
    output logic        a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 20'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 20'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
