// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x763.md.
// ttl_74x763 - octal buffer/line driver, inverting, complementary enables (OC).
// Inverting twin of 74x741 (which mirrored 74x241 non-inverting). One bank
// active-low OE, the other active-high OE.
module ttl_74x763 (
    input  logic [7:0] a,
    input  logic       oe1_n,
    input  logic       oe2,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'hf : ~a[3:0];
    assign y[7:4] = oe2   ? ~a[7:4] : 4'hf;
endmodule
