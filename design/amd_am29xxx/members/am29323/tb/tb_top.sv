module tb_top (
  input  logic        clk_i,
  input  logic [31:0] x_i, y_i,
  input  logic [3:0]  px_i, py_i,
  input  logic [31:0] p_i,
  output logic [31:0] p_o,
  output logic        p_oe_o,
  input  logic [3:0]  pp_i,
  output logic [3:0]  pp_o,
  output logic        pp_oe_o,
  input  logic        parerr_i,
  output logic        parerr_o,
  output logic        parerr_oe_o,
  output logic        harderr_o,
  input  logic        tcx_i, tcy_i,
  input  logic        acc0_i, acc1_i,
  input  logic        rnd_i,
  input  logic        tsel_i, fa_i,
  input  logic        psel0_i, psel1_i,
  input  logic        enxa_n_i, enxb_n_i,
  input  logic        enya_n_i, enyb_n_i,
  input  logic        enp_n_i, eni_n_i, ent_n_i,
  input  logic        ftx_i, fty_i, fti_i, ftp_i,
  input  logic        xsel_i, ysel_i,
  input  logic        oe_n_i,
  input  logic        slave_i
);
  amd_am29323 dut (.*);
endmodule
