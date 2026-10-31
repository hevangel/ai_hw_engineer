// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x32244.md.
// ttl_74x32244 - 32-bit non-inverting buffer/driver (3-state). Widebus 74x244.
module ttl_74x32244 (
    input  logic [31:0] a,
    input  logic        oe1_n, oe2_n, oe3_n, oe4_n,
    output logic [31:0] y
);
    assign y[7:0]   = oe1_n ? 8'h00 : a[7:0];
    assign y[15:8]  = oe2_n ? 8'h00 : a[15:8];
    assign y[23:16] = oe3_n ? 8'h00 : a[23:16];
    assign y[31:24] = oe4_n ? 8'h00 : a[31:24];
endmodule
