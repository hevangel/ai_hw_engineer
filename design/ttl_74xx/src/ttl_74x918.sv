// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x918.md.
// ttl_74x918 - Dual 2-input NAND 30V / 250mA relay driver (MM74C918).
// 14-pin sibling of ttl_74x908; logically two NAND gates.
module ttl_74x918 (
    input  logic [1:0] a,
    input  logic [1:0] b,
    output logic [1:0] y
);
    assign y = ~(a & b);
endmodule
