// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16541.md.
// ttl_74x16541 - 16-bit non-inverting buffer/driver with grouped 8-bit /OEs.
module ttl_74x16541 (
    input  logic [15:0] a,
    input  logic        oe1_n, oe2_n,
    output logic [15:0] y
);
    assign y[7:0]  = oe1_n ? 8'h00 : a[7:0];
    assign y[15:8] = oe2_n ? 8'h00 : a[15:8];
endmodule
