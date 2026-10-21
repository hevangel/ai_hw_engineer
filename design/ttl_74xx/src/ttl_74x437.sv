// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x437.md.
// ttl_74x437 - MOS memory interface line driver (same as 74x436).
module ttl_74x437 (
    input  logic [3:0] a,
    output logic [3:0] y
);
    assign y = a;
endmodule
