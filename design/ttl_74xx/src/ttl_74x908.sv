// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x908.md.
// ttl_74x908 - Dual 2-input NAND relay driver (MM74C908).
// 8-pin package; logically two NAND gates. The 30V/250 mA drive
// characteristics are not modeled in synthesizable RTL.
module ttl_74x908 (
    input  logic [1:0] a,
    input  logic [1:0] b,
    output logic [1:0] y
);
    assign y = ~(a & b);
endmodule
