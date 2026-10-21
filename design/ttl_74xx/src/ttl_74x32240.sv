// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x32240.md.
// ttl_74x32240 - 32-bit inverting buffer/driver (3-state). Widebus 74x240.
// Four 8-bit half-banks, each with its own active-low /OE.
module ttl_74x32240 (
    input  logic [31:0] a,
    input  logic        oe1_n, oe2_n, oe3_n, oe4_n,
    output logic [31:0] y
);
    assign y[7:0]   = oe1_n ? 8'h00 : ~a[7:0];
    assign y[15:8]  = oe2_n ? 8'h00 : ~a[15:8];
    assign y[23:16] = oe3_n ? 8'h00 : ~a[23:16];
    assign y[31:24] = oe4_n ? 8'h00 : ~a[31:24];
endmodule
