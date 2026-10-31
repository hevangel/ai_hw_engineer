// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x22501.md.
// ttl_74x22501 - 8-bit universal bus transceiver and two 1-bit bus transceivers.
// One 8-bit 245-style transceiver plus two independent 1-bit transceivers.
module ttl_74x22501 (
    // 8-bit section
    input  logic       oe_n, dir,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz,
    // 1-bit section #1
    input  logic       oe1_n, dir1,
    input  logic       a1_in, b1_in,
    output logic       a1_out, b1_out,
    // 1-bit section #2
    input  logic       oe2_n, dir2,
    input  logic       a2_in, b2_in,
    output logic       a2_out, b2_out
);
    assign b_out = (!oe_n &&  dir) ? a_in : 8'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 8'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
    assign b1_out = (!oe1_n &&  dir1) ? a1_in : 1'b0;
    assign a1_out = (!oe1_n && !dir1) ? b1_in : 1'b0;
    assign b2_out = (!oe2_n &&  dir2) ? a2_in : 1'b0;
    assign a2_out = (!oe2_n && !dir2) ? b2_in : 1'b0;
endmodule
