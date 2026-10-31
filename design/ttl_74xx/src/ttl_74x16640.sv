// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16640.md.
// ttl_74x16640 - 16-bit bus transceiver, inverting (3-state). Widebus 640.
module ttl_74x16640 (
    input  logic        dir, oe_n,
    input  logic [15:0] a_in, b_in,
    output logic [15:0] a_out, b_out,
    output logic        a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? ~a_in : 16'h0000;
    assign a_out = (!oe_n && !dir) ? ~b_in : 16'h0000;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
