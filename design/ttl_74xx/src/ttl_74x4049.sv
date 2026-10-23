// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4049.md.
// ttl_74x4049 - Hex inverting buffer / level translator.
module ttl_74x4049 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = ~a;
endmodule
