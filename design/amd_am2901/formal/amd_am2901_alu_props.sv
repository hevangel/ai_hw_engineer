`timescale 1ns/1ps
`ifdef FORMAL
module amd_am2901_alu_props (
    input logic [3:0] r_i, s_i,
    input logic [2:0] function_i,
    input logic cn_i
);
  logic [3:0] f;
  logic cn4, pn, gn, ov, sign_f, zero_f;
  integer x,y,p,g,total,carry3;
  logic [3:0] expected;
  logic ep,eg,ec,eo;
  logic [4:0] inverse_chain;
  amd_am2901_alu dut (.r_i(r_i),.s_i(s_i),.function_i(function_i),.cn_i(cn_i),
      .f_o(f),.cn4_o(cn4),.p_n_o(pn),.g_n_o(gn),.ovr_o(ov),.f3_o(sign_f),.zero_o(zero_f));
  // Independent manufacturer-table model: integer addition and signed overflow.
  always_comb begin
    x=int'(r_i); y=int'(s_i);
    if (function_i==1 || function_i==5 || function_i==6) x=15-x;
    if (function_i==2) y=15-y;
    p=x|y; g=x&y; total=x+y+int'(cn_i); carry3=(x&7)+(y&7)+int'(cn_i);
    expected=4'(total); ep=(p!=15); eg=(x+y<16); ec=(total>=16);
    eo=((x<8)==(y<8)) && ((int'(expected)<8)!=(x<8));
    inverse_chain={4'b0,cn_i};
    for (int k=0;k<4;k++) inverse_chain[k+1]=!p[k] || (!g[k] && inverse_chain[k]);
    case (function_i)
      3,6: begin
        expected=function_i==3 ? (r_i|s_i):(r_i^s_i);
        ep=0; eg=(p==15); ec=(p!=15)||cn_i; eo=ec;
      end
      4,5: begin expected=4'(g); ep=0; eg=(g==0); ec=(g==0)&&!cn_i; eo=ec; end
      7: begin
        expected=~(r_i^s_i); ep=(g!=0);
        eg=g[3] || (p[3]&&g[2]) || (p[3]&&p[2]&&g[1]) || (p==15);
        ec=!(g[3] || (p[3]&&g[2]) || (p[3]&&p[2]&&g[1]) || ((p==15)&&(g[0]||!cn_i)));
        eo=inverse_chain[3]!=inverse_chain[4];
      end
      default: ;
    endcase
    assert(f==expected);
    assert({pn,gn,cn4,ov}=={ep,eg,ec,eo});
    assert(sign_f==f[3] && zero_f==(f==0));
    if (function_i<3) assert(ov==((carry3>=8)!=(total>=16)));
  end
  always_ff @($global_clock) begin
    for (int k=0;k<8;k++) cover(function_i==3'(k) && cn_i && f==0);
    cover(function_i==0 && ov && cn4);
    cover(function_i==1 && ov && !cn4);
  end
endmodule
`endif
