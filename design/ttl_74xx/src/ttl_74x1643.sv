// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1643.md.
// ttl_74x1643 - Octal bus transceiver, true/inverting (3-state, lower-power variant of 74x643).
module ttl_74x1643 (
    input  logic       gab, gba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out
);
    assign b_out =  gab   ?  a_in : 8'b0;
    assign a_out = !gba_n ? ~b_in : 8'b0;
endmodule
