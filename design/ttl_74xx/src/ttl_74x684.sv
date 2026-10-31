// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x684.md.
// ttl_74x684 - 8-bit magnitude comparator (totem-pole, no Q pullups).
// Logically identical to 74x682; differs only in input pull-ups.
module ttl_74x684 (
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_eq_q_n,
    output logic       p_gt_q_n
);
    assign p_eq_q_n = (p == q) ? 1'b0 : 1'b1;
    assign p_gt_q_n = (p >  q) ? 1'b0 : 1'b1;
endmodule
