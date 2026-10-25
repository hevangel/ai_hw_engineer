// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x522.md.
// ttl_74x522 - 8-bit identity comparator, inverting, OC equivalent.
module ttl_74x522 (
    input  logic [7:0] p, q,
    input  logic       g_n,
    output logic       p_eq_q_n
);
    assign p_eq_q_n = !(!g_n && (p == q));
endmodule
