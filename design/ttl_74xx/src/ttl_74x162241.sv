// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x162241.md.
// ttl_74x162241 - 16-bit non-inverting buffer/driver (3-state), complementary enables.
// Logically follows the 74x241 pattern (one half active-low, other active-high) scaled to 16 bits.
module ttl_74x162241 (
    input  logic [15:0] a,
    input  logic        oe1_n,
    input  logic        oe2,
    output logic [15:0] y
);
    assign y[7:0]  = oe1_n ? 8'h00 : a[7:0];
    assign y[15:8] = oe2   ? a[15:8] : 8'h00;
endmodule
