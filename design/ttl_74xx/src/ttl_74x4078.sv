// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4078.md.
// ttl_74x4078 - Single 8-input OR/NOR gate.
module ttl_74x4078 (
    input  logic [7:0] a,
    output logic       y_or,
    output logic       y_nor
);
    assign y_or  =  |a;
    assign y_nor = ~|a;
endmodule
