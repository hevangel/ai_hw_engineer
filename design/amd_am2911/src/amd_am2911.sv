`timescale 1ns/1ps
module amd_am2911 (
    input logic cp_i,
    input logic [1:0] select_i,
    input logic [3:0] d_i,
    input logic re_n_i,fe_n_i,push_i,zero_n_i,oe_n_i,cn_i,
    output logic [3:0] y_o,
    output logic y_oe_o,cn4_o
);
  // Manufacturer Figure 2: R and D connected, address OR inputs removed.
  amd_am2909 engine (.cp_i(cp_i),.select_i(select_i),.d_i(d_i),.r_i(d_i),.or_i(4'b0),
      .re_n_i(re_n_i),.fe_n_i(fe_n_i),.push_i(push_i),.zero_n_i(zero_n_i),.oe_n_i(oe_n_i),.cn_i(cn_i),
      .y_o(y_o),.y_oe_o(y_oe_o),.cn4_o(cn4_o));
endmodule
