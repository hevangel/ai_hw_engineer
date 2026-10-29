// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1641.md.
// ttl_74x1641 - Octal bus transceiver, non-inverting (OC, lower-power variant of 74x641).
module ttl_74x1641 (
    input  logic       gab, gba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out
);
    assign b_out =  gab   ? a_in : 8'b0;
    assign a_out = !gba_n ? b_in : 8'b0;
endmodule
