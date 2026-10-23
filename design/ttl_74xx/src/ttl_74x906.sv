// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x906.md.
// ttl_74x906 - Hex open-drain n-channel buffer (MM74C906).
// Logically equivalent to a non-inverting buffer; OC drive is documentation only.
module ttl_74x906 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
