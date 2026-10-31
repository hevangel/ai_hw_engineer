// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x566.md.
// ttl_74x566 - 8-bit bidirectional registered transceiver, inverting.
module ttl_74x566 (
    input  logic       clkab, clkba, oeab_n, oeba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    logic [7:0] ab_reg, ba_reg;
    always_ff @(posedge clkab) ab_reg <= a_in;
    always_ff @(posedge clkba) ba_reg <= b_in;
    assign b_out = !oeab_n ? ~ab_reg : 8'b0;
    assign a_out = !oeba_n ? ~ba_reg : 8'b0;
    assign a_hiz = oeba_n;
    assign b_hiz = oeab_n;
endmodule
