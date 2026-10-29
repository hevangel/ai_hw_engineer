// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7541.md.
// ttl_74x7541 - Octal buffer/line driver, non-inverting (= 74x541).
module ttl_74x7541 (
    input  logic       oe1_n, oe2_n,
    input  logic [7:0] a,
    output logic [7:0] y,
    output logic       hiz
);
    wire en_n = oe1_n | oe2_n;
    assign y   = en_n ? 8'b0 : a;
    assign hiz = en_n;
endmodule
