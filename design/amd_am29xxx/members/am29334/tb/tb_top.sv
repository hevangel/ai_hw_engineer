module tb_top (
  input  logic [5:0]  ara_i, awa_i, arb_i, awb_i,
  input  logic [17:0] da_i, db_i,
  output logic [17:0] ya_o, yb_o,
  output logic        ya_oe_o, yb_oe_o,
  input  logic        lea_i, leb_i,
  input  logic        oea_n_i, oeb_n_i,
  input  logic        wea_c_n_i, wea_l_n_i, wea_h_n_i,
  input  logic        web_c_n_i, web_l_n_i, web_h_n_i
);
  amd_am29334 dut (.*);
endmodule
