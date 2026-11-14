module tb_top (
  input  logic        qclk_i, dqclk_i,
  input  logic        qen_n_i, dqen_n_i,
  input  logic [1:0]  bq_i,
  input  logic [3:0]  bdq_i,
  input  logic [1:0]  bsw_i,
  input  logic [31:0] d_i,
  input  logic [3:0]  pd_i,
  input  logic [1:0]  pos_i,
  input  logic        reset_n_i, rxmit_n_i,
  input  logic        oe_n_i,
  output logic [31:0] y_o,
  output logic        y_oe_o,
  output logic [3:0]  py_o,
  output logic        pyerr_o,
  output logic        pderr_o,
  output logic [6:0]  cnt_o,
  output logic        full_o, a_full_o, empty_o, a_empty_o
);
  amd_am29338 dut (.*);
endmodule
