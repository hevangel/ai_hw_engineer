// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1808.md.
// ttl_74x1808 - Hex 2-input AND gate.
module ttl_74x1808 (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);
    assign y = a & b;
endmodule
