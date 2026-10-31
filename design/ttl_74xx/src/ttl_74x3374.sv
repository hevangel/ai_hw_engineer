// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x3374.md.
// ttl_74x3374 - 8-bit "metastable-resistant" D-type flip-flop (= 74x374).
// The metastability-resistance is a physical attribute; the logic matches '374.
module ttl_74x3374 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] q_reg;
    always_ff @(posedge clk) q_reg <= d;
    assign q = oe_n ? 8'h00 : q_reg;
endmodule
