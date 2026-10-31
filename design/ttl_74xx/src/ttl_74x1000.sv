// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1000.md.
// ttl_74x1000 - Quad 2-input NAND gate (driver). High-drive variant of 74x00.
module ttl_74x1000 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a & b);
endmodule
