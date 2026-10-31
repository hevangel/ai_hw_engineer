// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16240.md.
// ttl_74x16240 - 16-bit inverting buffer/driver with grouped 4-bit /OE (3-state).
// Widebus 16-bit version of 74x240 with four independent 4-bit groups.
module ttl_74x16240 (
    input  logic [15:0] a,
    input  logic        oe1_n, oe2_n, oe3_n, oe4_n,
    output logic [15:0] y
);
    assign y[3:0]   = oe1_n ? 4'h0 : ~a[3:0];
    assign y[7:4]   = oe2_n ? 4'h0 : ~a[7:4];
    assign y[11:8]  = oe3_n ? 4'h0 : ~a[11:8];
    assign y[15:12] = oe4_n ? 4'h0 : ~a[15:12];
endmodule
