module tb_top (
  input  logic        clk_i,
  input  logic [15:0] d_i,
  input  logic        enl_n_i, enu_n_i,
  input  logic        signed_i,
  input  logic        cil_i, ciu_i,
  output logic        col_o, cou_o, oob_o
);
  amd_am29337 dut (.*);
endmodule
