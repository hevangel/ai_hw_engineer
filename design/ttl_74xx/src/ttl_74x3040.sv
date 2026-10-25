// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x3040.md.
// ttl_74x3040 - Dual 4-input NAND gate (= 74x20).
module ttl_74x3040 (
    input  logic [3:0] a, b,
    output logic [1:0] y
);
    assign y[0] = ~&{a[0], a[1], a[2], a[3]};
    assign y[1] = ~&{b[0], b[1], b[2], b[3]};
endmodule
