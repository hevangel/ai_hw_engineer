// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16827.md.
// ttl_74x16827 - 20-bit non-inverting buffer/driver (3-state). Two 10-bit halves.
module ttl_74x16827 (
    input  logic [19:0] a,
    input  logic        oe1_n, oe2_n,
    output logic [19:0] y
);
    assign y[9:0]   = oe1_n ? 10'h000 : a[9:0];
    assign y[19:10] = oe2_n ? 10'h000 : a[19:10];
endmodule
