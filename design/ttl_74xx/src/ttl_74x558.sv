// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x558.md.
// ttl_74x558 - 8-bit by 8-bit unsigned multiplier (variant of 74x557).
module ttl_74x558 (
    input  logic [7:0]  a, b,
    output logic [15:0] product
);
    assign product = a * b;
endmodule
