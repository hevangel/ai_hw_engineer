`timescale 1ns/1ps
// AMD 1974 Data Book pp. 2-55, 2-59. CE_INPUTS represents the two packages.
// The physical CD-bar pin is HIGH for UP. No reset exists on the real part.
module amd_am2501 #(
    parameter int CE_INPUTS = 6
) (
    input logic cp_i,
    input logic cd_n_i,
    input logic pe_n_i,
    input logic [CE_INPUTS-1:0] ce_i,
    input logic [3:0] p_i,
    output logic [3:0] q_o,
    output logic tc_o
);
  always_ff @(posedge cp_i) begin
    if (!pe_n_i)
      q_o <= p_i;
    else if (&ce_i)
      q_o <= cd_n_i ? q_o + 4'd1 : q_o - 4'd1;
  end

  assign tc_o = cd_n_i ? &q_o : ~|q_o;

`ifdef FORMAL
  always_comb begin
    assert (tc_o == (cd_n_i ? (q_o == 4'hf) : (q_o == 0)));
  end
`endif
endmodule
