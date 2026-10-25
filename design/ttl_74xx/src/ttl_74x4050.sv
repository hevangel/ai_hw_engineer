// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4050.md.
// ttl_74x4050 - Hex non-inverting buffer / level translator.
module ttl_74x4050 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
