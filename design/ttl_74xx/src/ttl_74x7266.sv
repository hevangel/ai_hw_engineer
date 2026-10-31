// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7266.md.
// ttl_74x7266 - Quad 2-input XNOR gate.
module ttl_74x7266 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = ~(a ^ b);
endmodule
