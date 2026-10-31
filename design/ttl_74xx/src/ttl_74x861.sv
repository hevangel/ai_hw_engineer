// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x861.md.
// ttl_74x861 - 10-bit bus transceiver, non-inverting (3-state).
//
// Per SN74ABT861 datasheet (SCBS199C): two independent active-low enables
// /OEAB and /OEBA. /OEAB low drives B from A; /OEBA low drives A from B.
// Both high = isolation. Both low = bidirectional drive (used as a bus
// "latch" via the natural feedback).
module ttl_74x861 (
    input  logic       oeab_n,
    input  logic       oeba_n,
    input  logic [9:0] a_in,
    input  logic [9:0] b_in,
    output logic [9:0] a_out,
    output logic [9:0] b_out,
    output logic       a_oe_n,
    output logic       b_oe_n
);
    assign b_oe_n = oeab_n;
    assign a_oe_n = oeba_n;
    assign b_out  = oeab_n ? 10'h000 : a_in;
    assign a_out  = oeba_n ? 10'h000 : b_in;
endmodule
