// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x425.md.
// ttl_74x425 - Quad bus buffer, active-low enables, 3-state outputs.
module ttl_74x425 (
    input  logic [3:0] a,
    input  logic [3:0] oe_n,
    output logic [3:0] y
);
    always_comb for (int i = 0; i < 4; i++) y[i] = oe_n[i] ? 1'b0 : a[i];
endmodule
