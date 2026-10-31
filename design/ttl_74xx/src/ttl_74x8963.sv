// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8963.md.
// ttl_74x8963 - 9-bit bidirectional latched FutureBus transceiver, non-inverting.
module ttl_74x8963 (
    input  logic       leab, oeab_n,
    input  logic       leba, oeba_n,
    input  logic [8:0] a_in, b_in,
    output logic [8:0] a_out, b_out
);
    logic [8:0] ab_q, ba_q;
    always_latch if (leab) ab_q = a_in;
    always_latch if (leba) ba_q = b_in;
    assign b_out = oeab_n ? 9'b0 : ab_q;
    assign a_out = oeba_n ? 9'b0 : ba_q;
endmodule
