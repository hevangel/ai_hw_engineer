`timescale 1ns/1ps
module amd_am2901_alu (
    input logic [3:0] r_i, s_i,
    input logic [2:0] function_i,
    input logic cn_i,
    output logic [3:0] f_o,
    output logic cn4_o, p_n_o, g_n_o, ovr_o, f3_o, zero_o
);
  logic [3:0] r, s, p, g;
  logic [4:0] carry;
  logic group_generate;
  logic [3:0] np, ng;
  logic x3, x4;
  always_comb begin
    r = r_i; s = s_i;
    if (function_i == 3'd1 || function_i == 3'd5 || function_i == 3'd6) r = ~r_i;
    if (function_i == 3'd2) s = ~s_i;
    p = r | s; g = r & s;
    carry={4'b0000,cn_i};
    carry[1]=g[0] | (p[0]&cn_i);
    carry[2]=g[1] | (p[1]&g[0]) | (p[1]&p[0]&cn_i);
    carry[3]=g[2] | (p[2]&g[1]) | (p[2]&p[1]&g[0]) | (p[2]&p[1]&p[0]&cn_i);
    carry[4]=g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) | (p[3]&p[2]&p[1]&g[0]) | (p[3]&p[2]&p[1]&p[0]&cn_i);
    group_generate = g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) | (p[3]&p[2]&p[1]&g[0]);
    p_n_o = ~(&p); g_n_o = ~group_generate;
    cn4_o = carry[4]; ovr_o = carry[3]^carry[4];
    f_o = r ^ s ^ carry[3:0];
    np = ~p; ng = ~g;
    x3 = np[2] | (ng[2]&np[1]) | (ng[2]&ng[1]&np[0]) | (ng[2]&ng[1]&ng[0]&cn_i);
    x4 = np[3] | (ng[3]&np[2]) | (ng[3]&ng[2]&np[1]) |
         (ng[3]&ng[2]&ng[1]&np[0]) | (ng[3]&ng[2]&ng[1]&ng[0]&cn_i);
    case (function_i)
      3'd3,3'd6: begin
        f_o = function_i==3'd3 ? (r_i|s_i) : (r_i^s_i);
        p_n_o=0; g_n_o=&p; cn4_o=~(&p)|cn_i; ovr_o=cn4_o;
      end
      3'd4,3'd5: begin
        f_o=g; p_n_o=0; g_n_o=~(|g); cn4_o=~((|g)|cn_i); ovr_o=cn4_o;
      end
      3'd7: begin
        f_o=~(r_i^s_i); p_n_o=|g;
        g_n_o=g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) | (p[3]&p[2]&p[1]&p[0]);
        cn4_o=~(g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) |
                (p[3]&p[2]&p[1]&p[0]&(g[0]|~cn_i)));
        ovr_o=x3^x4;
      end
      default: ;
    endcase
    f3_o=f_o[3]; zero_o=(f_o==0);
  end
endmodule
