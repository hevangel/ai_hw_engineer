// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1003.md.
// ttl_74x1003 - Quad 2-input NAND gate (OC driver). OC variant of 74x1000.
module ttl_74x1003 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a & b);
endmodule
