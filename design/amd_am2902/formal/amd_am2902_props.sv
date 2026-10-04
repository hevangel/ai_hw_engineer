`timescale 1ns/1ps
`ifdef FORMAL
module amd_am2902_props (
    input logic [3:0] p_n_i,g_n_i,
    input logic cn_i
);
  logic [2:0] carry;
  logic pn,gn;
  logic [4:0] ripple,generated;
  amd_am2902 dut (.p_n_i(p_n_i),.g_n_i(g_n_i),.cn_i(cn_i),.carry_o(carry),.p_n_o(pn),.g_n_o(gn));
  assign ripple[0]=cn_i; assign generated[0]=0;
  for (genvar stage=0;stage<4;stage++) begin: stages
    assign ripple[stage+1]=!g_n_i[stage] || (!p_n_i[stage] && ripple[stage]);
    assign generated[stage+1]=!g_n_i[stage] || (!p_n_i[stage] && generated[stage]);
  end
  always_comb begin
    assert(carry==ripple[3:1]);
    assert(gn==!generated[4] && pn==(|p_n_i));
    assert(ripple[4]==(!gn || (!pn && cn_i)));
  end
  always_ff @($global_clock) begin
    cover(p_n_i==15 && g_n_i==15 && carry==0);
    cover(p_n_i==0 && g_n_i==15 && cn_i && carry==7 && !pn && gn);
    cover(p_n_i==0 && g_n_i==15 && !cn_i && carry==0 && !pn && gn);
    cover(p_n_i==15 && g_n_i==0 && carry==7 && pn && !gn);
    cover(p_n_i==0 && g_n_i==0 && !gn && !pn);
  end
endmodule
`endif
