// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x340.md.
// ttl_74x340 - Octal inverting buffer, 3-state (same as 74x240).
module ttl_74x340 (
    input  logic [7:0] a,
    input  logic       oe1_n, oe2_n,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'h0 : ~a[3:0];
    assign y[7:4] = oe2_n ? 4'h0 : ~a[7:4];
endmodule
