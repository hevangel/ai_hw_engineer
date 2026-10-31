// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x828.md.
// ttl_74x828 - 10-bit buffer / line driver, inverting (3-state).
// Inverting twin of ttl_74x827; both /OE1 and /OE2 must be low to enable outputs.
module ttl_74x828 (
    input  logic [9:0] d,
    input  logic       oe1_n,
    input  logic       oe2_n,
    output logic [9:0] q,
    output logic       q_oe_n
);
    assign q_oe_n = oe1_n | oe2_n;
    assign q      = q_oe_n ? 10'b0 : ~d;
endmodule
