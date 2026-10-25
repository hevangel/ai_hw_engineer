// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x162240.md.
// ttl_74x162240 - 16-bit inverting buffer/driver (3-state).
// Two 8-bit halves, each with its own active-low /OE.
module ttl_74x162240 (
    input  logic [15:0] a,
    input  logic        oe1_n, oe2_n,
    output logic [15:0] y
);
    assign y[7:0]  = oe1_n ? 8'h00 : ~a[7:0];
    assign y[15:8] = oe2_n ? 8'h00 : ~a[15:8];
endmodule
