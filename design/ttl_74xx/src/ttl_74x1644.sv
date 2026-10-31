// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1644.md.
// ttl_74x1644 - Octal bus transceiver, true/inverting (OC, lower-power variant of 74x644).
module ttl_74x1644 (
    input  logic       gab, gba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out
);
    assign b_out =  gab   ?  a_in : 8'b0;
    assign a_out = !gba_n ? ~b_in : 8'b0;
endmodule
