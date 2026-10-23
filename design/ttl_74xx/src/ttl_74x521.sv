// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x521.md.
// ttl_74x521 - 8-bit identity comparator, inverting (active-low p_eq_q_n).
module ttl_74x521 (
    input  logic [7:0] p, q,
    input  logic       g_n,
    output logic       p_eq_q_n
);
    assign p_eq_q_n = !(!g_n && (p == q));
endmodule
