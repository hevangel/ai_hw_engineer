// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1034.md.
// ttl_74x1034 - Hex non-inverting buffer (driver). High-drive variant of 74x34.
module ttl_74x1034 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
