// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7008.md.
// ttl_74x7008 - Mixed gate package: two inverters, three 2-input NAND,
// three 2-input NOR.
module ttl_74x7008 (
    input  logic [1:0] inv_a,
    output logic [1:0] inv_y,
    input  logic [2:0] nand_a, nand_b,
    output logic [2:0] nand_y,
    input  logic [2:0] nor_a, nor_b,
    output logic [2:0] nor_y
);
    assign inv_y  = ~inv_a;
    assign nand_y = ~(nand_a & nand_b);
    assign nor_y  = ~(nor_a  | nor_b);
endmodule
