`timescale 1ns/1ps
module amd_am2902 (
    input logic [3:0] p_n_i,g_n_i,
    input logic cn_i,
    output logic [2:0] carry_o,
    output logic p_n_o,g_n_o
);
  logic [3:0] p,g;
  assign p=~p_n_i; assign g=~g_n_i;
  assign carry_o[0]=g[0] | (p[0]&cn_i);
  assign carry_o[1]=g[1] | (p[1]&g[0]) | (p[1]&p[0]&cn_i);
  assign carry_o[2]=g[2] | (p[2]&g[1]) | (p[2]&p[1]&g[0]) | (p[2]&p[1]&p[0]&cn_i);
  assign p_n_o=~(&p);
  assign g_n_o=~(g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) | (p[3]&p[2]&p[1]&g[0]));
endmodule
