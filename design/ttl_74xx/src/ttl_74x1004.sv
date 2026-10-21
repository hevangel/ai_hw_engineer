// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1004.md.
// ttl_74x1004 - Hex inverting buffer (driver). High-drive variant of 74x04.
module ttl_74x1004 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = ~a;
endmodule
