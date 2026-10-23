// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x746.md.
// ttl_74x746 - octal buffer/line driver, inverting (3-state, 20 kΩ input pull-ups).
// Logically identical to 74x240; the 20 kΩ pull-ups on the A inputs are noted
// in the datasheet but not modeled.
module ttl_74x746 (
    input  logic [7:0] a,
    input  logic       oe1_n, oe2_n,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'h0 : ~a[3:0];
    assign y[7:4] = oe2_n ? 4'h0 : ~a[7:4];
endmodule
