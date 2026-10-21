// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16540.md.
// ttl_74x16540 - 16-bit inverting buffer/driver with grouped 8-bit /OEs.
// Widebus relative of 74x540 (octal inverting buffer with single /OE) scaled to 16 bits.
module ttl_74x16540 (
    input  logic [15:0] a,
    input  logic        oe1_n, oe2_n,
    output logic [15:0] y
);
    assign y[7:0]  = oe1_n ? 8'h00 : ~a[7:0];
    assign y[15:8] = oe2_n ? 8'h00 : ~a[15:8];
endmodule
