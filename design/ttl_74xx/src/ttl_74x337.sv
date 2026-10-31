// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x337.md.
// ttl_74x337 - Clock driver (buffer).
module ttl_74x337 (
    input  logic [7:0] a,
    output logic [7:0] y
);
    assign y = a;
endmodule
