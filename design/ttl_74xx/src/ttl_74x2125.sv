// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2125.md.
// ttl_74x2125 - Quad bus buffer with 3-state outputs (series-resistor variant of 74x125).
module ttl_74x2125 (
    input  logic [3:0] a,
    input  logic [3:0] oe_n,
    output logic [3:0] y
);
    always_comb begin
        for (int i = 0; i < 4; i++) y[i] = oe_n[i] ? 1'b0 : a[i];
    end
endmodule
