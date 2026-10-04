`timescale 1ns/1ps
module tb_top (
    input logic cp_i,
    input logic [1:0] select_i,
    input logic [11:0] d_i,r_i,or_i,
    input logic re_n_i,fe_n_i,push_i,zero_n_i,oe_n_i,cn_i,
    output logic [11:0] y_o,
    output logic y_oe_o,cn12_o
);
  logic [3:0] carry;
  logic [2:0] enabled;
  assign carry[0]=cn_i; assign cn12_o=carry[3];assign y_oe_o=&enabled;
  for (genvar slice=0;slice<3;slice++) begin: sequencers
    amd_am2909 dut (.cp_i(cp_i),.select_i(select_i),.d_i(d_i[slice*4+:4]),.r_i(r_i[slice*4+:4]),.or_i(or_i[slice*4+:4]),
        .re_n_i(re_n_i),.fe_n_i(fe_n_i),.push_i(push_i),.zero_n_i(zero_n_i),.oe_n_i(oe_n_i),.cn_i(carry[slice]),
        .y_o(y_o[slice*4+:4]),.y_oe_o(enabled[slice]),.cn4_o(carry[slice+1]));
  end
endmodule
