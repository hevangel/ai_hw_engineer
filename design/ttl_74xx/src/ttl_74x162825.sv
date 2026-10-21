// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x162825.md.
// ttl_74x162825 - 3.3-V 18-bit non-inverting buffer/driver (3-state).
module ttl_74x162825 (
    input  logic [17:0] a,
    input  logic        oe1_n, oe2_n,
    output logic [17:0] y
);
    assign y[8:0]   = oe1_n ? 9'h000 : a[8:0];
    assign y[17:9]  = oe2_n ? 9'h000 : a[17:9];
endmodule
