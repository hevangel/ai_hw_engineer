// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x620.md.
// ttl_74x620 - octal bus transceiver, inverting outputs (3-state).
module ttl_74x620 (
    input  logic       gab, gba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    assign b_out =  gab    ? ~a_in : 8'b0;
    assign a_out = !gba_n  ? ~b_in : 8'b0;
    assign b_hiz = !gab;
    assign a_hiz =  gba_n;
endmodule
