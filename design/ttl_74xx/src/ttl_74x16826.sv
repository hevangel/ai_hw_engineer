// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16826.md.
// ttl_74x16826 - 18-bit inverting buffer/driver (3-state). Two 9-bit halves.
module ttl_74x16826 (
    input  logic [17:0] a,
    input  logic        oe1_n, oe2_n,
    output logic [17:0] y
);
    assign y[8:0]  = oe1_n ? 9'h000 : ~a[8:0];
    assign y[17:9] = oe2_n ? 9'h000 : ~a[17:9];
endmodule
