// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x689.md.
// ttl_74x689 - 8-bit identity comparator with /G enable (open-collector).
module ttl_74x689 (
    input  logic       g_n,
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_eq_q_n
);
    assign p_eq_q_n = (!g_n && (p == q)) ? 1'b0 : 1'b1;
endmodule
