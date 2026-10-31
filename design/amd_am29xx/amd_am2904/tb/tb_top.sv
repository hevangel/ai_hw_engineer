module tb_top (
  input logic cp_i,
  input logic [12:0] instruction_i,
  input logic [3:0] status_i, y_i, shift_i,
  input logic cx_i, ceu_n_i, cem_n_i,
  input logic [3:0] e_n_i,
  input logic oey_n_i, oect_n_i, se_n_i,
  output logic [3:0] y_o, shift_o, shift_oe_o,
  output logic y_oe_o, ct_o, ct_oe_o, carry_o
);
  amd_am2904 dut(.*);
endmodule
