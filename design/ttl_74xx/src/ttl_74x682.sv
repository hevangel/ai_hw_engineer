// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x682.md.
// ttl_74x682 - 8-bit magnitude / identity comparator (totem-pole, Q-side 20 kΩ pullups).
//
// Per the SN74LS682/684/685/686/687/688 family datasheet (SDLS008): no enable
// inputs, both /P=Q and /P>Q outputs are active-low (asserted when the named
// condition holds). The 20 kΩ pullups on the Q inputs are documented in the
// datasheet but not modeled in synthesizable RTL.
module ttl_74x682 (
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_eq_q_n,
    output logic       p_gt_q_n
);
    assign p_eq_q_n = (p == q) ? 1'b0 : 1'b1;
    assign p_gt_q_n = (p >  q) ? 1'b0 : 1'b1;
endmodule
