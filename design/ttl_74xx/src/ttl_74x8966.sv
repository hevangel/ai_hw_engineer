// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8966.md.
// ttl_74x8966 - 9-bit bidirectional latched FutureBus transceiver with
// idle arbitration request / output.
// Same data path as ttl_74x8963 plus an active-low arbitration request
// output that asserts whenever the chip is idle (both OEs are deasserted).
module ttl_74x8966 (
    input  logic       leab, oeab_n,
    input  logic       leba, oeba_n,
    input  logic [8:0] a_in, b_in,
    output logic [8:0] a_out, b_out,
    output logic       idle_n
);
    logic [8:0] ab_q, ba_q;
    always_latch if (leab) ab_q = a_in;
    always_latch if (leba) ba_q = b_in;
    assign b_out  = oeab_n ? 9'b0 : ab_q;
    assign a_out  = oeba_n ? 9'b0 : ba_q;
    assign idle_n = ~(oeab_n & oeba_n);
endmodule
