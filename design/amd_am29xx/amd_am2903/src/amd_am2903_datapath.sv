module amd_am2903_datapath (
  input logic [8:0] instruction_i,
  input logic [3:0] r_i, s_i, q_i, y_i,
  input logic sc_i, cn_i, z_i, ien_n_i, oe_y_n_i,
  input logic lss_n_i, mss_n_i,
  input logic sio0_i, sio3_i, qio0_i, qio3_i,
  output logic [3:0] y_o, q_next_o,
  output logic q_enable_o, sc_enable_o, sc_next_o,
  output logic cn4_o, gn_o, povr_o, z_pull_low_o, write_n_o,
  output logic [3:0] shift_o, shift_oe_o
);
  logic [3:0] f, gi, pi;
  logic [4:0] carry;
  logic g, p, arithmetic, special, mss, lss;
  logic [3:0] function_code, destination;
  logic [1:0] q_action;
  logic zero_value, zero_enable;
  assign special=instruction_i[4:0]==0;
  assign function_code=instruction_i[4:1];
  assign destination=instruction_i[8:5];
  assign lss=!lss_n_i;
  assign mss=lss_n_i && !mss_n_i;
  always_comb begin
    f=0;gi=0;pi=15;arithmetic=0;
    if(!special) begin
      case(function_code)
        0: f=15;
        1: begin f=s_i-r_i-4'd1+4'(cn_i);gi=~r_i&s_i;pi=~r_i|s_i;arithmetic=1;end
        2: begin f=r_i-s_i-4'd1+4'(cn_i);gi=r_i&~s_i;pi=r_i|~s_i;arithmetic=1;end
        3: begin f=r_i+s_i+4'(cn_i);gi=r_i&s_i;pi=r_i|s_i;arithmetic=1;end
        4: begin f=s_i+4'(cn_i);pi=s_i;arithmetic=1;end
        5: begin f=(~s_i)+4'(cn_i);pi=~s_i;arithmetic=1;end
        6: begin f=r_i+4'(cn_i);pi=r_i;arithmetic=1;end
        7: begin f=(~r_i)+4'(cn_i);pi=~r_i;arithmetic=1;end
        8: f=0;
        9: begin f=~r_i&s_i;gi=~r_i&s_i;end
        10: begin f=~(r_i^s_i);gi=~r_i&s_i;pi=~r_i|s_i;end
        11: begin f=r_i^s_i;gi=~r_i&s_i;pi=~r_i|s_i;end
        12: begin f=r_i&~s_i;gi=r_i&~s_i;end
        13: begin f=~(r_i|s_i);gi=~r_i&~s_i;end
        14: begin f=~(r_i&s_i);gi=r_i&s_i;end
        15: begin f=r_i|s_i;gi=~r_i&~s_i;end
        default: begin end
      endcase
    end else begin
      arithmetic=1;
      case(destination)
        0,2: begin
          f=s_i+4'(cn_i);pi=s_i;
          if(z_i) begin f=r_i+s_i+4'(cn_i);gi=r_i&s_i;pi=r_i|s_i;end
        end
        4: begin
          // Table5 low slice injects the additional +1 into the carry chain.
          f=s_i+4'(cn_i)+4'(lss);pi=s_i;
          if(lss) begin gi={3'b0,s_i[0]};pi={s_i[3:1],1'b1};end
        end
        5: begin f=s_i+4'(cn_i);pi=s_i;
          if(z_i) begin f=(~s_i)+4'(cn_i);pi=~s_i;end
        end
        6: begin f=s_i+4'(cn_i);pi=s_i;
          if(z_i) begin f=s_i-r_i-4'd1+4'(cn_i);gi=~r_i&s_i;pi=~r_i|s_i;end
        end
        8,10: begin f=s_i+4'(cn_i);pi=s_i;end
        12,14: begin
          f=s_i+r_i+4'(cn_i);gi=r_i&s_i;pi=r_i|s_i;
          if(z_i) begin f=s_i-r_i-4'd1+4'(cn_i);gi=~r_i&s_i;pi=~r_i|s_i;end
          // Special E follows corrected 1979 AMD Table5, not 1978 print error.
        end
        default: begin f=0;arithmetic=0;end
      endcase
    end
  end
  assign carry[0]=cn_i;
  for(genvar i=0;i<4;i++) begin: carry_chain
    assign carry[i+1]=gi[i] | (pi[i]&carry[i]);
  end
  assign g=gi[3] | (pi[3]&gi[2]) | (pi[3]&pi[2]&gi[1]) | (pi[3]&pi[2]&pi[1]&gi[0]);
  assign p=&pi;
  always_comb begin
    cn4_o=arithmetic ? carry[4]:1'b0;
    gn_o=mss ? f[3]:!g;
    povr_o=arithmetic ? (mss ? carry[3]^carry[4]:!p):1'b0;
    if(special && mss) begin
      case(destination)
        5: if(z_i) gn_o=f[3]^s_i[3];
        8: begin cn4_o=q_i[3]^q_i[2];povr_o=q_i[2]^q_i[1];gn_o=q_i[3];end
        10: begin cn4_o=f[3]^f[2];povr_o=f[2]^f[1];end
        default: begin end
      endcase
    end
  end
  always_comb begin
    y_o=f;shift_o=0;shift_oe_o=0;q_action=0;write_n_o=0;
    if(!special) begin
      case(destination)
        0,2: begin y_o=mss ? {f[3],sio3_i,f[2:1]}:{sio3_i,f[3:1]};shift_o[0]=f[0];shift_oe_o[0]=1;end
        1,3: begin y_o={sio3_i,f[3:1]};shift_o[0]=f[0];shift_oe_o[0]=1;end
        4,5,6,7: begin shift_o[0]=(^f)^sio3_i;shift_oe_o[0]=1;end
        8,10: begin y_o=mss ? {f[3],f[1:0],sio0_i}:{f[2:0],sio0_i};shift_o[1]=mss ? f[2]:f[3];shift_oe_o[1]=1;end
        9,11: begin y_o={f[2:0],sio0_i};shift_o[1]=f[3];shift_oe_o[1]=1;end
        12,13,15: begin shift_o[1]=f[3];shift_oe_o[1]=1;end
        14: begin y_o={4{sio0_i}};shift_o[1]=sio0_i;shift_oe_o[1]=1;end
        default: begin end
      endcase
      case(destination)
        2,3,5: q_action=1;
        6,7: q_action=3;
        10,11,13: q_action=2;
        default: begin end
      endcase
      write_n_o=destination==5 || destination==6 || destination==12 || destination==13;
    end else begin
      case(destination)
        0,2,6: begin
          y_o={sio3_i,f[3:1]};
          if(mss) y_o[3]=destination==0 ? carry[4]:f[3]^carry[3]^carry[4];
          shift_o[0]=f[0];shift_oe_o[0]=1;q_action=1;
        end
        4,5: begin
          shift_o[0]=(^f)^sio3_i;shift_oe_o[0]=1;
          if(destination==5 && mss) y_o[3]=f[3]^s_i[3];
        end
        8: begin shift_o[1]=f[3];shift_oe_o[1]=1;q_action=2;end
        10,12: begin
          y_o={f[2:0],sio0_i};shift_o[1]=mss ? ~(r_i[3]^f[3]):f[3];shift_oe_o[1]=1;q_action=2;
        end
        14: begin shift_o[1]=f[3];shift_oe_o[1]=1;q_action=2;end
        // ASSUMPTION: reserved special codes do not update storage.
        default: begin y_o=0;write_n_o=1;end
      endcase
    end
    q_next_o=q_i;
    case(q_action)
      1: begin q_next_o={qio3_i,q_i[3:1]};shift_o[2]=q_i[0];shift_oe_o[2]=1;end
      2: begin q_next_o={q_i[2:0],qio0_i};shift_o[3]=q_i[3];shift_oe_o[3]=1;end
      3: q_next_o=f;
      default: begin end
    endcase
    q_enable_o=!ien_n_i && q_action!=0;
    sc_enable_o=!ien_n_i && special && (destination==10 || destination==12);
    sc_next_o=~(r_i[3]^f[3]);
    if(ien_n_i) write_n_o=1;
  end
  always_comb begin
    zero_enable=1;
    zero_value=(oe_y_n_i ? y_i:y_o)==0;
    if(special) begin
      case(destination)
        0,2,6: begin zero_enable=lss;zero_value=q_i[0];end
        5: begin zero_enable=mss;zero_value=s_i[3];end
        8: zero_value=q_i==0;
        10: zero_value=(q_i|f)==0;
        12,14: begin zero_enable=mss;zero_value=sc_i;end
        default: begin end
      endcase
    end
    z_pull_low_o=zero_enable && !zero_value;
  end
`ifdef FORMAL
  `include "manufacturer_datapath.svh"
`endif
endmodule
