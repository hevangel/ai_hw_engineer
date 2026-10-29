// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7002.md.
// ttl_74x7002 - Quad 2-input NOR gate (= 74x02).
module ttl_74x7002 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = ~(a | b);
endmodule
