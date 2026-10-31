// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x524.md.
// ttl_74x524 - 8-bit registered identity comparator.
module ttl_74x524 (
    input  logic       clk, g_n,
    input  logic [7:0] p, q,
    output logic       p_eq_q
);
    logic [7:0] p_reg, q_reg;
    always_ff @(posedge clk) begin
        p_reg <= p;
        q_reg <= q;
    end
    assign p_eq_q = !g_n && (p_reg == q_reg);
endmodule
