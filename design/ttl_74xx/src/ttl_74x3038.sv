// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x3038.md.
// ttl_74x3038 - Quad 2-input NAND gate (= 74x00).
module ttl_74x3038 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a & b);
endmodule
