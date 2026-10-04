module tb_top (
  input logic cp_i,
  input logic [3:0] instruction_i,
  input logic [11:0] d_i,
  input logic cc_n_i, ccen_n_i, ci_i, rld_n_i, oe_n_i,
  output logic [11:0] y_o,
  output logic y_oe_o, full_n_o, pl_n_o, map_n_o, vect_n_o
);
  amd_am2910 dut (.*);
endmodule
