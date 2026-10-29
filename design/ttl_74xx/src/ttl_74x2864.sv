// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2864.md.
// ttl_74x2864 - 9-bit inverting bus transceiver with dual output enable.
module ttl_74x2864 (
    input  logic        oea_n, oeb_n,
    input  logic [8:0]  a_in, b_in,
    output logic [8:0]  a_out, b_out,
    output logic        a_hiz, b_hiz
);
    assign a_out = !oea_n ? ~b_in : 9'b0;
    assign b_out = !oeb_n ? ~a_in : 9'b0;
    assign a_hiz = oea_n;
    assign b_hiz = oeb_n;
endmodule
