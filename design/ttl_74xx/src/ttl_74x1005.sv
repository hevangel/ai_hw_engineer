// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1005.md.
// ttl_74x1005 - Hex inverting buffer (OC driver). OC variant of 74x1004.
module ttl_74x1005 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = ~a;
endmodule
