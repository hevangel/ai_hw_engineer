// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74ls460.md.
// ttl_74ls460 - 10-bit comparator.
module ttl_74ls460 (
    input  logic [9:0] a, b,
    output logic       a_eq_b,
    output logic       a_gt_b,
    output logic       a_lt_b
);
    assign a_eq_b = (a == b);
    assign a_gt_b = (a >  b);
    assign a_lt_b = (a <  b);
endmodule
