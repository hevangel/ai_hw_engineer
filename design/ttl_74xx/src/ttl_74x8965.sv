// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8965.md.
// ttl_74x8965 - 9-bit bidirectional latched FutureBus transceiver, latch select.
// Like ttl_74x8963 but with a per-direction `sel_q` that chooses between
// real-time pass-through and the latched value (similar to 74x646).
module ttl_74x8965 (
    input  logic       leab, sab, oeab_n,
    input  logic       leba, sba, oeba_n,
    input  logic [8:0] a_in, b_in,
    output logic [8:0] a_out, b_out
);
    logic [8:0] ab_q, ba_q;
    always_latch if (leab) ab_q = a_in;
    always_latch if (leba) ba_q = b_in;
    assign b_out = oeab_n ? 9'b0 : (sab ? ab_q : a_in);
    assign a_out = oeba_n ? 9'b0 : (sba ? ba_q : b_in);
endmodule
