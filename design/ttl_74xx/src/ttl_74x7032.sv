// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7032.md.
// ttl_74x7032 - Quad 2-input OR gate (= 74x32).
module ttl_74x7032 (
    input  logic [3:0] a, b,
    output logic [3:0] y
);
    assign y = a | b;
endmodule
