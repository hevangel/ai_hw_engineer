// Generated from original manufacturer CSVs; no RTL inspection.
logic [3:0] mf,mg,mp,my,mq,ms,me;
logic [4:0] mc;
logic mcn,mgn,mpov,mz,mwrite,mqe,msc;
logic mpn,mgn_n;
always_comb begin
  mf=0;mg=0;mp=15;
  if(instruction_i[4:0]!=0) begin
    case(instruction_i[4:1])
      4'd0: begin mf=4'd15;mg=4'd0;mp=4'd15;end
      4'd1: begin mf=(((s_i-r_i)-4'd1)+4'(cn_i));mg=(~(r_i)&s_i);mp=(~(r_i)|s_i);end
      4'd2: begin mf=(((r_i-s_i)-4'd1)+4'(cn_i));mg=(r_i&~(s_i));mp=(r_i|~(s_i));end
      4'd3: begin mf=((r_i+s_i)+4'(cn_i));mg=(r_i&s_i);mp=(r_i|s_i);end
      4'd4: begin mf=(s_i+4'(cn_i));mg=4'd0;mp=s_i;end
      4'd5: begin mf=(~(s_i)+4'(cn_i));mg=4'd0;mp=~(s_i);end
      4'd6: begin mf=(r_i+4'(cn_i));mg=4'd0;mp=r_i;end
      4'd7: begin mf=(~(r_i)+4'(cn_i));mg=4'd0;mp=~(r_i);end
      4'd8: begin mf=4'd0;mg=4'd0;mp=4'd15;end
      4'd9: begin mf=(~(r_i)&s_i);mg=(~(r_i)&s_i);mp=4'd15;end
      4'd10: begin mf=~((r_i^s_i));mg=(~(r_i)&s_i);mp=(~(r_i)|s_i);end
      4'd11: begin mf=(r_i^s_i);mg=(~(r_i)&s_i);mp=(~(r_i)|s_i);end
      4'd12: begin mf=(r_i&~(s_i));mg=(r_i&~(s_i));mp=4'd15;end
      4'd13: begin mf=~((r_i|s_i));mg=(~(r_i)&~(s_i));mp=4'd15;end
      4'd14: begin mf=~((r_i&s_i));mg=(r_i&s_i);mp=4'd15;end
      4'd15: begin mf=(r_i|s_i);mg=(~(r_i)&~(s_i));mp=4'd15;end
    endcase
  end else begin
    case(instruction_i[8:5])
      4'd0: begin mf=(!(z_i) ? (s_i+4'(cn_i)) : ((r_i+s_i)+4'(cn_i)));mg=(!(z_i) ? 4'd0 : (r_i&s_i));mp=(!(z_i) ? s_i : (r_i|s_i));end
      4'd2: begin mf=(!(z_i) ? (s_i+4'(cn_i)) : ((r_i+s_i)+4'(cn_i)));mg=(!(z_i) ? 4'd0 : (r_i&s_i));mp=(!(z_i) ? s_i : (r_i|s_i));end
      4'd4: begin mf=((s_i+(lss ? 4'd1 : 4'd0))+4'(cn_i));mg=(lss ? (s_i&4'd1) : 4'd0);mp=(lss ? (s_i|4'd1) : s_i);end
      4'd5: begin mf=(!(z_i) ? (s_i+4'(cn_i)) : (~(s_i)+4'(cn_i)));mg=4'd0;mp=(!(z_i) ? s_i : ~(s_i));end
      4'd6: begin mf=(!(z_i) ? (s_i+4'(cn_i)) : (((s_i-r_i)-4'd1)+4'(cn_i)));mg=(!(z_i) ? 4'd0 : (~(r_i)&s_i));mp=(!(z_i) ? s_i : (~(r_i)|s_i));end
      4'd8: begin mf=(s_i+4'(cn_i));mg=4'd0;mp=s_i;end
      4'd10: begin mf=(s_i+4'(cn_i));mg=4'd0;mp=s_i;end
      4'd12: begin mf=(!(z_i) ? ((s_i+r_i)+4'(cn_i)) : (((s_i-r_i)-4'd1)+4'(cn_i)));mg=(!(z_i) ? (r_i&s_i) : (~(r_i)&s_i));mp=(!(z_i) ? (r_i|s_i) : (~(r_i)|s_i));end
      4'd14: begin mf=(!(z_i) ? ((s_i+r_i)+4'(cn_i)) : (((s_i-r_i)-4'd1)+4'(cn_i)));mg=(!(z_i) ? (r_i&s_i) : (~(r_i)&s_i));mp=(!(z_i) ? (r_i|s_i) : (~(r_i)|s_i));end
      default: begin end
    endcase
  end
end
assign mc[0]=cn_i;
for(genvar k=0;k<4;k++) begin: table_carry
 assign mc[k+1]=mg[k]|(mp[k]&mc[k]);
end
assign mpn=!(&mp);
assign mgn_n=!(mg[3]|(mg[2]&mp[3])|(mg[1]&mp[2]&mp[3])|(mg[0]&mp[1]&mp[2]&mp[3]));
always_comb begin
 my=0;mq=q_i;ms=0;me=0;mcn=0;mgn=0;mpov=0;mz=0;mwrite=1;mqe=0;msc=0;
 if(instruction_i[4:0]!=0) begin
 case(instruction_i[8:5])
  4'd0: begin my=mss ? (((mf&4'd8)|(sio3_i<<4'd2))|((mf>>4'd1)&4'd3)):((sio3_i<<4'd3)|(mf>>4'd1));ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=mf[0];me[0]=1'b1;mwrite=ien_n_i || 1'b0;mq=q_i;mqe=0;end
  4'd1: begin my=mss ? ((sio3_i<<4'd3)|(mf>>4'd1)):((sio3_i<<4'd3)|(mf>>4'd1));ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=mf[0];me[0]=1'b1;mwrite=ien_n_i || 1'b0;mq=q_i;mqe=0;end
  4'd2: begin my=mss ? (((mf&4'd8)|(sio3_i<<4'd2))|((mf>>4'd1)&4'd3)):((sio3_i<<4'd3)|(mf>>4'd1));ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=mf[0];me[0]=1'b1;mwrite=ien_n_i || 1'b0;mq={qio3_i,q_i[3:1]};mqe=!ien_n_i;ms[2]=q_i[0];me[2]=1;end
  4'd3: begin my=mss ? ((sio3_i<<4'd3)|(mf>>4'd1)):((sio3_i<<4'd3)|(mf>>4'd1));ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=mf[0];me[0]=1'b1;mwrite=ien_n_i || 1'b0;mq={qio3_i,q_i[3:1]};mqe=!ien_n_i;ms[2]=q_i[0];me[2]=1;end
  4'd4: begin my=mss ? mf:mf;ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=(^mf)^sio3_i;me[0]=1'b1;mwrite=ien_n_i || 1'b0;mq=q_i;mqe=0;end
  4'd5: begin my=mss ? mf:mf;ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=(^mf)^sio3_i;me[0]=1'b1;mwrite=ien_n_i || 1'b1;mq={qio3_i,q_i[3:1]};mqe=!ien_n_i;ms[2]=q_i[0];me[2]=1;end
  4'd6: begin my=mss ? mf:mf;ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=(^mf)^sio3_i;me[0]=1'b1;mwrite=ien_n_i || 1'b1;mq=mf;mqe=!ien_n_i;end
  4'd7: begin my=mss ? mf:mf;ms[1]=mss ? (1'b0):(1'b0);me[1]=mss ? 1'b0:1'b0;ms[0]=(^mf)^sio3_i;me[0]=1'b1;mwrite=ien_n_i || 1'b0;mq=mf;mqe=!ien_n_i;end
  4'd8: begin my=mss ? (((mf&4'd8)|((mf<<4'd1)&4'd6))|sio0_i):(((mf<<4'd1)|sio0_i)&4'd15);ms[1]=mss ? (mf[2]):(mf[3]);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b0;mq=q_i;mqe=0;end
  4'd9: begin my=mss ? (((mf<<4'd1)|sio0_i)&4'd15):(((mf<<4'd1)|sio0_i)&4'd15);ms[1]=mss ? (mf[3]):(mf[3]);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b0;mq=q_i;mqe=0;end
  4'd10: begin my=mss ? (((mf&4'd8)|((mf<<4'd1)&4'd6))|sio0_i):(((mf<<4'd1)|sio0_i)&4'd15);ms[1]=mss ? (mf[2]):(mf[3]);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b0;mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;end
  4'd11: begin my=mss ? (((mf<<4'd1)|sio0_i)&4'd15):(((mf<<4'd1)|sio0_i)&4'd15);ms[1]=mss ? (mf[3]):(mf[3]);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b0;mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;end
  4'd12: begin my=mss ? mf:mf;ms[1]=mss ? (mf[3]):(mf[3]);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b1;mq=q_i;mqe=0;end
  4'd13: begin my=mss ? mf:mf;ms[1]=mss ? (mf[3]):(mf[3]);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b1;mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;end
  4'd14: begin my=mss ? (4'd15*sio0_i):(4'd15*sio0_i);ms[1]=mss ? (sio0_i):(sio0_i);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b0;mq=q_i;mqe=0;end
  4'd15: begin my=mss ? mf:mf;ms[1]=mss ? (mf[3]):(mf[3]);me[1]=mss ? 1'b1:1'b1;ms[0]=1'b0;me[0]=1'b0;mwrite=ien_n_i || 1'b0;mq=q_i;mqe=0;end
 endcase
 case(instruction_i[4:1])
  4'd0: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd1: begin mcn=mc[4];mgn=mss ? mf[3]:mgn_n;mpov=(mss ? (mc[3]^mc[4]):mpn);end
  4'd2: begin mcn=mc[4];mgn=mss ? mf[3]:mgn_n;mpov=(mss ? (mc[3]^mc[4]):mpn);end
  4'd3: begin mcn=mc[4];mgn=mss ? mf[3]:mgn_n;mpov=(mss ? (mc[3]^mc[4]):mpn);end
  4'd4: begin mcn=mc[4];mgn=mss ? mf[3]:mgn_n;mpov=(mss ? (mc[3]^mc[4]):mpn);end
  4'd5: begin mcn=mc[4];mgn=mss ? mf[3]:mgn_n;mpov=(mss ? (mc[3]^mc[4]):mpn);end
  4'd6: begin mcn=mc[4];mgn=mss ? mf[3]:mgn_n;mpov=(mss ? (mc[3]^mc[4]):mpn);end
  4'd7: begin mcn=mc[4];mgn=mss ? mf[3]:mgn_n;mpov=(mss ? (mc[3]^mc[4]):mpn);end
  4'd8: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd9: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd10: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd11: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd12: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd13: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd14: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
  4'd15: begin mcn=0;mgn=mss ? mf[3]:mgn_n;mpov=0;end
 endcase
 mz=(oe_y_n_i ? y_i:my)!=0;
 end else begin
 case(instruction_i[8:5])
  4'd0: begin my=(mss ? ((mc[4]<<4'd3)|(mf>>4'd1)) : ((sio3_i<<4'd3)|(mf>>4'd1)));ms[0]=mf[0];me[0]=1'b1;ms[1]=1'b0;me[1]=1'b0;mq={qio3_i,q_i[3:1]};mqe=!ien_n_i;ms[2]=q_i[0];me[2]=1;mwrite=ien_n_i;mcn=mss ? mc[4]:mc[4];mpov=mss ? (mc[3]^mc[4]):mpn;mgn=mss ? mf[3]:mgn_n;mz=lss && !q_i[0];msc=0;end
  4'd2: begin my=(mss ? (((mf[3]^(mc[3]^mc[4]))<<4'd3)|(mf>>4'd1)) : ((sio3_i<<4'd3)|(mf>>4'd1)));ms[0]=mf[0];me[0]=1'b1;ms[1]=1'b0;me[1]=1'b0;mq={qio3_i,q_i[3:1]};mqe=!ien_n_i;ms[2]=q_i[0];me[2]=1;mwrite=ien_n_i;mcn=mss ? mc[4]:mc[4];mpov=mss ? (mc[3]^mc[4]):mpn;mgn=mss ? mf[3]:mgn_n;mz=lss && !q_i[0];msc=0;end
  4'd4: begin my=mf;ms[0]=(^mf)^sio3_i;me[0]=1'b1;ms[1]=1'b0;me[1]=1'b0;mq=q_i;mqe=0;mwrite=ien_n_i;mcn=mss ? mc[4]:mc[4];mpov=mss ? (mc[3]^mc[4]):mpn;mgn=mss ? mf[3]:mgn_n;mz=(oe_y_n_i ? y_i:my)!=0;msc=0;end
  4'd5: begin my=(mss ? ((mf&4'd7)|((mf[3]^s_i[3])<<4'd3)) : mf);ms[0]=(^mf)^sio3_i;me[0]=1'b1;ms[1]=1'b0;me[1]=1'b0;mq=q_i;mqe=0;mwrite=ien_n_i;mcn=mss ? mc[4]:mc[4];mpov=mss ? (mc[3]^mc[4]):mpn;mgn=mss ? (!(z_i) ? mf[3] : (mf[3]^s_i[3])):mgn_n;mz=mss && !s_i[3];msc=0;end
  4'd6: begin my=(mss ? (((mf[3]^(mc[3]^mc[4]))<<4'd3)|(mf>>4'd1)) : ((sio3_i<<4'd3)|(mf>>4'd1)));ms[0]=mf[0];me[0]=1'b1;ms[1]=1'b0;me[1]=1'b0;mq={qio3_i,q_i[3:1]};mqe=!ien_n_i;ms[2]=q_i[0];me[2]=1;mwrite=ien_n_i;mcn=mss ? mc[4]:mc[4];mpov=mss ? (mc[3]^mc[4]):mpn;mgn=mss ? mf[3]:mgn_n;mz=lss && !q_i[0];msc=0;end
  4'd8: begin my=mf;ms[0]=1'b0;me[0]=1'b0;ms[1]=mf[3];me[1]=1'b1;mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;mwrite=ien_n_i;mcn=mss ? (q_i[3]^q_i[2]):mc[4];mpov=mss ? (q_i[2]^q_i[1]):mpn;mgn=mss ? q_i[3]:mgn_n;mz=q_i!=0;msc=0;end
  4'd10: begin my=(((mf<<4'd1)|sio0_i)&4'd15);ms[0]=1'b0;me[0]=1'b0;ms[1]=mss ? ~(r_i[3]^mf[3]):mf[3];me[1]=1'b1;mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;mwrite=ien_n_i;mcn=mss ? (mf[3]^mf[2]):mc[4];mpov=mss ? (mf[2]^mf[1]):mpn;mgn=mss ? mf[3]:mgn_n;mz=(q_i|mf)!=0;msc=!ien_n_i;end
  4'd12: begin my=(((mf<<4'd1)|sio0_i)&4'd15);ms[0]=1'b0;me[0]=1'b0;ms[1]=mss ? ~(r_i[3]^mf[3]):mf[3];me[1]=1'b1;mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;mwrite=ien_n_i;mcn=mss ? mc[4]:mc[4];mpov=mss ? (mc[3]^mc[4]):mpn;mgn=mss ? mf[3]:mgn_n;mz=mss && !sc_i;msc=!ien_n_i;end
  4'd14: begin my=mf;ms[0]=1'b0;me[0]=1'b0;ms[1]=mf[3];me[1]=1'b1;mq={q_i[2:0],qio0_i};mqe=!ien_n_i;ms[3]=q_i[3];me[3]=1;mwrite=ien_n_i;mcn=mss ? mc[4]:mc[4];mpov=mss ? (mc[3]^mc[4]):mpn;mgn=mss ? mf[3]:mgn_n;mz=mss && !sc_i;msc=0;end
 default: begin end
 endcase
 end
end
always_comb begin
 if(instruction_i[4:0]!=0 || instruction_i[8:5]==4'd0 || instruction_i[8:5]==4'd2 || instruction_i[8:5]==4'd4 || instruction_i[8:5]==4'd5 || instruction_i[8:5]==4'd6 || instruction_i[8:5]==4'd8 || instruction_i[8:5]==4'd10 || instruction_i[8:5]==4'd12 || instruction_i[8:5]==4'd14) begin
 assert(f==mf && gi==mg && pi==mp);
 assert(y_o==my && cn4_o==mcn && gn_o==mgn && povr_o==mpov);
 assert(z_pull_low_o==mz && write_n_o==mwrite);
 assert(shift_o==ms && shift_oe_o==me);
 assert(q_enable_o==mqe && sc_enable_o==msc);
 if(mqe) assert(q_next_o==mq);
 if(msc) assert(sc_next_o==~(r_i[3]^mf[3]));
 end
end
always_ff @($global_clock) begin
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd0 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd2 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd4 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd5 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd6 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd8 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd10 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd12 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]==0 && instruction_i[8:5]==4'd14 && !ien_n_i && mss && r_i!=s_i && cn_i);
 cover(instruction_i[4:0]!=0 && instruction_i[8:5]==14 && y_o==15);
 cover(instruction_i[4:0]!=0 && instruction_i[8:5]==6 && q_enable_o);
end
