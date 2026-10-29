// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1020.md.
// ttl_74x1020 - Dual 4-input NAND gate (driver). High-drive variant of 74x20.
module ttl_74x1020 (
    input  logic [3:0] a1, a2,
    output logic       y1, y2
);
    assign y1 = ~&a1;
    assign y2 = ~&a2;
endmodule
