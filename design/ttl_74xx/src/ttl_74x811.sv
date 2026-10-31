// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x811.md.
// ttl_74x811 - quad 2-input XNOR gates, open-collector outputs.
module ttl_74x811 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = ~(a ^ b);
endmodule
