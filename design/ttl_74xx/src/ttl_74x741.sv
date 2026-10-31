// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x741.md.
// ttl_74x741 - dual 4-bit line driver, non-inverting, complementary enables (3-state).
// Functional twin of 74x241: one bank active-low OE, the other active-high OE.
module ttl_74x741 (
    input  logic [7:0] a,
    input  logic       oe1_n,
    input  logic       oe2,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'h0 : a[3:0];
    assign y[7:4] = oe2   ? a[7:4] : 4'h0;
endmodule
