// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x864.md.
// ttl_74x864 - 9-bit bus transceiver, inverting (3-state).
// Inverting-data sibling of ttl_74x863.
module ttl_74x864 (
    input  logic       oeab_n,
    input  logic       oeba_n,
    input  logic [8:0] a_in,
    input  logic [8:0] b_in,
    output logic [8:0] a_out,
    output logic [8:0] b_out,
    output logic       a_oe_n,
    output logic       b_oe_n
);
    assign b_oe_n = oeab_n;
    assign a_oe_n = oeba_n;
    assign b_out  = oeab_n ? 9'b0 : ~a_in;
    assign a_out  = oeba_n ? 9'b0 : ~b_in;
endmodule
