// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1035.md.
// ttl_74x1035 - Hex non-inverting buffer (OC driver). OC twin of 74x1034.
module ttl_74x1035 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
