// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8003.md.
// ttl_74x8003 - Dual 2-input NAND gate (compact variant of 74x00).
module ttl_74x8003 (
    input  logic [1:0] a, b,
    output logic [1:0] y
);
    assign y = ~(a & b);
endmodule
