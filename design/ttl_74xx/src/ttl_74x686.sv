// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x686.md.
// ttl_74x686 - 8-bit magnitude comparator with separate enables on each output (totem-pole).
//
// Per SDLS008: g1_n enables the /P=Q output; g2_n enables the /P>Q output.
// When an enable is high, its output is forced high (inactive).
module ttl_74x686 (
    input  logic       g1_n,
    input  logic       g2_n,
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_eq_q_n,
    output logic       p_gt_q_n
);
    assign p_eq_q_n = (!g1_n && (p == q)) ? 1'b0 : 1'b1;
    assign p_gt_q_n = (!g2_n && (p >  q)) ? 1'b0 : 1'b1;
endmodule
