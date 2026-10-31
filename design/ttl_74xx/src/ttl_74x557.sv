// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x557.md.
// ttl_74x557 - 8-bit by 8-bit unsigned multiplier.
module ttl_74x557 (
    input  logic [7:0]  a, b,
    output logic [15:0] product
);
    assign product = a * b;
endmodule
