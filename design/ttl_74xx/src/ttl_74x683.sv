// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x683.md.
// ttl_74x683 - 8-bit magnitude comparator (open-collector, Q-side 20 kΩ pullups).
// Logically identical to 74x682; differs only in output drive style.
module ttl_74x683 (
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_eq_q_n,
    output logic       p_gt_q_n
);
    assign p_eq_q_n = (p == q) ? 1'b0 : 1'b1;
    assign p_gt_q_n = (p >  q) ? 1'b0 : 1'b1;
endmodule
