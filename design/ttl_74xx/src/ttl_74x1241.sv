// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1241.md.
// ttl_74x1241 - Octal buffer/line driver, non-inverting, complementary enables.
// Lower-power variant of 74x241.
module ttl_74x1241 (
    input  logic [7:0] a,
    input  logic       oe1_n,
    input  logic       oe2,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'h0 : a[3:0];
    assign y[7:4] = oe2   ? a[7:4] : 4'h0;
endmodule
