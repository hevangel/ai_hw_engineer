// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x518.md.
// ttl_74x518 - 8-bit identity comparator, OC active-high output (digital model: active-high).
module ttl_74x518 (
    input  logic [7:0] p, q,
    input  logic       g_n,
    output logic       p_eq_q
);
    assign p_eq_q = !g_n && (p == q);
endmodule
