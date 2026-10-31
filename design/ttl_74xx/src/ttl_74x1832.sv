// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1832.md.
// ttl_74x1832 - Hex 2-input OR (lower-power variant of 74x832).
module ttl_74x1832 (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);
    assign y = a | b;
endmodule
