// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x543.md.
// ttl_74x543 - octal registered transceiver, non-inverting.
// Internal A->B and B->A latches; output enables on each side.
module ttl_74x543 (
    input  logic       leab_n, oeab_n, ceab_n,
    input  logic       leba_n, oeba_n, ceba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    logic [7:0] ab_reg, ba_reg;
    always_latch if (!leab_n && !ceab_n) ab_reg = a_in;
    always_latch if (!leba_n && !ceba_n) ba_reg = b_in;
    assign b_out = (!oeab_n && !ceab_n) ? ab_reg : 8'b0;
    assign a_out = (!oeba_n && !ceba_n) ? ba_reg : 8'b0;
    assign a_hiz = oeba_n || ceba_n;
    assign b_hiz = oeab_n || ceab_n;
endmodule
