// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4075.md.
// ttl_74x4075 - Triple 3-input OR gate.
module ttl_74x4075 (
    input  logic [2:0] a, b, c,
    output logic [2:0] y
);
    assign y[0] = |a;
    assign y[1] = |b;
    assign y[2] = |c;
endmodule
