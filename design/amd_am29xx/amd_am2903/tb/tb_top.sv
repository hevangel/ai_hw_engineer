module tb_top (
  input logic cp_i,
  input logic [8:0] instruction_i,
  input logic [3:0] a_i, b_i, da_i, db_i, y_i,
  input logic ea_i, oe_b_n_i, oe_y_n_i, we_n_i, ien_n_i, cn_i,
  input logic lss_n_i, mss_n_i, z_i,
  input logic sio0_i, sio3_i, qio0_i, qio3_i,
  output logic [3:0] y_o, db_o,
  output logic y_oe_o, db_oe_o, write_n_o, write_oe_o,
  output logic cn4_o, gn_o, povr_o, z_pull_low_o,
  output logic [3:0] shift_o, shift_oe_o
);
  amd_am2903 dut (.*);
endmodule
