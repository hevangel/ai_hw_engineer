// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7001.md.
// ttl_74x7001 - Quad 2-input AND gate (= 74x08).
module ttl_74x7001 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = a & b;
endmodule
