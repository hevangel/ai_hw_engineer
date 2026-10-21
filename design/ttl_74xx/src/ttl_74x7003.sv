// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7003.md.
// ttl_74x7003 - Quad 2-input NAND gate (= 74x00).
module ttl_74x7003 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = ~(a & b);
endmodule
