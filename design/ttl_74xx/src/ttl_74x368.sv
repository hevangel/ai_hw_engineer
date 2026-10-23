// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x368.md.
// ttl_74x368 - Hex buffer, inverting, 3-state, 4-bit and 2-bit banks.
module ttl_74x368 (
    input  logic [5:0] a,
    input  logic       g1_n, g2_n,
    output logic [5:0] y
);
    assign y[3:0] = g1_n ? 4'h0 : ~a[3:0];
    assign y[5:4] = g2_n ? 2'h0 : ~a[5:4];
endmodule
