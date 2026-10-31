// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x685.md.
// ttl_74x685 - 8-bit magnitude comparator (open-collector, no Q pullups).
// Logically identical to 74x684; OC drive style.
module ttl_74x685 (
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_eq_q_n,
    output logic       p_gt_q_n
);
    assign p_eq_q_n = (p == q) ? 1'b0 : 1'b1;
    assign p_gt_q_n = (p >  q) ? 1'b0 : 1'b1;
endmodule
