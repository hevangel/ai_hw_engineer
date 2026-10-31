// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x588.md.
// ttl_74x588 - octal bidirectional transceiver, IEEE-488 termination resistors on the bus side (digital model — ignores terminations).
module ttl_74x588 (
    input  logic       dir, oe_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 8'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 8'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
