// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1805.md.
// ttl_74x1805 - Hex 2-input NOR gate.
module ttl_74x1805 (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);
    assign y = ~(a | b);
endmodule
