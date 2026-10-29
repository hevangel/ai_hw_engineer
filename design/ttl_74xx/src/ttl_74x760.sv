// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x760.md.
// ttl_74x760 - octal buffer/line driver, non-inverting (OC).
// Logically identical to 74x244; Logical 1 releases the collector; board resolution uses wired AND.
module ttl_74x760 (
    input  logic [7:0] a,
    input  logic       oe1_n, oe2_n,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'hf : a[3:0];
    assign y[7:4] = oe2_n ? 4'hf : a[7:4];
endmodule
