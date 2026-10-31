// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x556.md.
// ttl_74x556 - 16x16-bit multiplier slice.
module ttl_74x556 (
    input  logic [15:0] a, b,
    output logic [31:0] product
);
    assign product = a * b;
endmodule
