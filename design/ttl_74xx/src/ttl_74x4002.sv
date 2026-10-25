// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4002.md.
// ttl_74x4002 - Dual 4-input NOR gate.
module ttl_74x4002 (
    input  logic [3:0] a, b,
    output logic [1:0] y
);
    assign y[0] = ~|a;
    assign y[1] = ~|b;
endmodule
