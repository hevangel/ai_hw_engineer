// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74ls547.md.
// ttl_74ls547 - 8-bit bidirectional latched transceiver, non-inverting.
module ttl_74ls547 (
    input  logic       leab, leba, oeab_n, oeba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    logic [7:0] ab_lat, ba_lat;
    always_latch if (leab) ab_lat = a_in;
    always_latch if (leba) ba_lat = b_in;
    assign b_out = !oeab_n ? ab_lat : 8'b0;
    assign a_out = !oeba_n ? ba_lat : 8'b0;
    assign a_hiz = oeba_n;
    assign b_hiz = oeab_n;
endmodule
