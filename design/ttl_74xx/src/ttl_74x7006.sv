// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7006.md.
// ttl_74x7006 - Mixed gate package: two inverters, one 3-input NAND,
// one 4-input NAND, one 3-input NOR, one 4-input NOR.
module ttl_74x7006 (
    input  logic [1:0] inv_a,
    output logic [1:0] inv_y,
    input  logic [2:0] nand3_a,
    output logic       nand3_y,
    input  logic [3:0] nand4_a,
    output logic       nand4_y,
    input  logic [2:0] nor3_a,
    output logic       nor3_y,
    input  logic [3:0] nor4_a,
    output logic       nor4_y
);
    assign inv_y   = ~inv_a;
    assign nand3_y = ~&nand3_a;
    assign nand4_y = ~&nand4_a;
    assign nor3_y  = ~|nor3_a;
    assign nor4_y  = ~|nor4_a;
endmodule
