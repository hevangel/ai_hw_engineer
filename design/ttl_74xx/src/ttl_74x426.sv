// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x426.md.
// ttl_74x426 - Quad bus buffer, active-high enables, 3-state outputs.
module ttl_74x426 (
    input  logic [3:0] a,
    input  logic [3:0] oe,
    output logic [3:0] y
);
    always_comb for (int i = 0; i < 4; i++) y[i] = oe[i] ? a[i] : 1'b0;
endmodule
