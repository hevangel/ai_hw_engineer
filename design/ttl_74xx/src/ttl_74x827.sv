// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x827.md.
// ttl_74x827 - 10-bit buffer / line driver, non-inverting (3-state).
//
// Per 74F827 datasheet (DS009598): a single 10-bit non-inverting buffer with
// two active-low output-enable inputs combined as an AND of their negations,
// i.e., outputs drive only when BOTH /OE1 and /OE2 are low.
module ttl_74x827 (
    input  logic [9:0] d,
    input  logic       oe1_n,
    input  logic       oe2_n,
    output logic [9:0] q,
    output logic       q_oe_n
);
    assign q_oe_n = oe1_n | oe2_n;
    assign q      = q_oe_n ? 10'b0 : d;
endmodule
