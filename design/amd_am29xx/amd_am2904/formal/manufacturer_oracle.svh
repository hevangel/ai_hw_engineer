// Generated from manufacturer CSV by generate_oracle.py; do not edit.
logic [3:0] gold_u, gold_m, gold_y, gold_shift, gold_shift_oe;
logic gold_y_oe, gold_ct, gold_ct_oe, gold_carry;
logic UZ,UC,UN,UV,MZ,MC,MN,MV,IZ,IC,IN,IV,YZ,YC,YN,YV,S0,SN,Q0,QN;
always_comb begin
{UV,UN,UC,UZ}=usr; {MV,MN,MC,MZ}=msr;
{IV,IN,IC,IZ}=status_i; {YV,YN,YC,YZ}=y_i; {QN,Q0,SN,S0}=shift_i;
gold_u=0; gold_m=0; gold_y=0; gold_ct=0; gold_carry=0;
gold_shift=0; gold_shift_oe=0;
gold_ct_oe=!oect_n_i; gold_y_oe=!oey_n_i && instruction_i[5:0]!=0;
case (instruction_i[5:0])
6'h00: begin gold_u={MV,MN,MC,MZ}; gold_m={YV,YN,YC,YZ}; gold_y=usr; gold_ct=((UN ^ UV) | UZ); gold_carry=UC; end
6'h01: begin gold_u={1'b1,1'b1,1'b1,1'b1}; gold_m={1'b1,1'b1,1'b1,1'b1}; gold_y=usr; gold_ct=(((UN ^ UV) ^ 1'b1) & (UZ ^ 1'b1)); gold_carry=UC; end
6'h02: begin gold_u={MV,MN,MC,MZ}; gold_m={UV,UN,UC,UZ}; gold_y=usr; gold_ct=(UN ^ UV); gold_carry=UC; end
6'h03: begin gold_u={1'b0,1'b0,1'b0,1'b0}; gold_m={1'b0,1'b0,1'b0,1'b0}; gold_y=usr; gold_ct=((UN ^ UV) ^ 1'b1); gold_carry=UC; end
6'h04: begin gold_u={IV,IN,IC,IZ}; gold_m={MC,IN,MV,IZ}; gold_y=usr; gold_ct=UZ; gold_carry=UC; end
6'h05: begin gold_u={IV,IN,IC,IZ}; gold_m={(MV ^ 1'b1),(MN ^ 1'b1),(MC ^ 1'b1),(MZ ^ 1'b1)}; gold_y=usr; gold_ct=(UZ ^ 1'b1); gold_carry=UC; end
6'h06: begin gold_u={(IV | UV),IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=UV; gold_carry=UC; end
6'h07: begin gold_u={(IV | UV),IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UV ^ 1'b1); gold_carry=UC; end
6'h08: begin gold_u={UV,UN,UC,1'b0}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=usr; gold_ct=(UC | UZ); gold_carry=(UC ^ 1'b1); end
6'h09: begin gold_u={UV,UN,UC,1'b1}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=usr; gold_ct=((UC ^ 1'b1) & (UZ ^ 1'b1)); gold_carry=(UC ^ 1'b1); end
6'h0a: begin gold_u={UV,UN,1'b0,UZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=UC; gold_carry=UC; end
6'h0b: begin gold_u={UV,UN,1'b1,UZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UC ^ 1'b1); gold_carry=UC; end
6'h0c: begin gold_u={UV,1'b0,UC,UZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=((UC ^ 1'b1) | UZ); gold_carry=UC; end
6'h0d: begin gold_u={UV,1'b1,UC,UZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UC & (UZ ^ 1'b1)); gold_carry=UC; end
6'h0e: begin gold_u={1'b0,UN,UC,UZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(IN ^ MN); gold_carry=UC; end
6'h0f: begin gold_u={1'b1,UN,UC,UZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=((IN ^ MN) ^ 1'b1); gold_carry=UC; end
6'h10: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=((UN ^ UV) | UZ); gold_carry=UC; end
6'h11: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(((UN ^ UV) ^ 1'b1) & (UZ ^ 1'b1)); gold_carry=UC; end
6'h12: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UN ^ UV); gold_carry=UC; end
6'h13: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=((UN ^ UV) ^ 1'b1); gold_carry=UC; end
6'h14: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=UZ; gold_carry=UC; end
6'h15: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UZ ^ 1'b1); gold_carry=UC; end
6'h16: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=UV; gold_carry=UC; end
6'h17: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UV ^ 1'b1); gold_carry=UC; end
6'h18: begin gold_u={IV,IN,(IC ^ 1'b1),IZ}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=usr; gold_ct=((UC ^ 1'b1) | UZ); gold_carry=(UC ^ 1'b1); end
6'h19: begin gold_u={IV,IN,(IC ^ 1'b1),IZ}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=usr; gold_ct=(UC & (UZ ^ 1'b1)); gold_carry=(UC ^ 1'b1); end
6'h1a: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=UC; gold_carry=UC; end
6'h1b: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UC ^ 1'b1); gold_carry=UC; end
6'h1c: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=((UC ^ 1'b1) | UZ); gold_carry=UC; end
6'h1d: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UC & (UZ ^ 1'b1)); gold_carry=UC; end
6'h1e: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=UN; gold_carry=UC; end
6'h1f: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=usr; gold_ct=(UN ^ 1'b1); gold_carry=UC; end
6'h20: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=((MN ^ MV) | MZ); gold_carry=MC; end
6'h21: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=(((MN ^ MV) ^ 1'b1) & (MZ ^ 1'b1)); gold_carry=MC; end
6'h22: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=(MN ^ MV); gold_carry=MC; end
6'h23: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=((MN ^ MV) ^ 1'b1); gold_carry=MC; end
6'h24: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=MZ; gold_carry=MC; end
6'h25: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=(MZ ^ 1'b1); gold_carry=MC; end
6'h26: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=MV; gold_carry=MC; end
6'h27: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=(MV ^ 1'b1); gold_carry=MC; end
6'h28: begin gold_u={IV,IN,(IC ^ 1'b1),IZ}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=msr; gold_ct=(MC | MZ); gold_carry=(MC ^ 1'b1); end
6'h29: begin gold_u={IV,IN,(IC ^ 1'b1),IZ}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=msr; gold_ct=((MC ^ 1'b1) & (MZ ^ 1'b1)); gold_carry=(MC ^ 1'b1); end
6'h2a: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=MC; gold_carry=MC; end
6'h2b: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=(MC ^ 1'b1); gold_carry=MC; end
6'h2c: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=((MC ^ 1'b1) | MZ); gold_carry=MC; end
6'h2d: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=(MC & (MZ ^ 1'b1)); gold_carry=MC; end
6'h2e: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=MN; gold_carry=MC; end
6'h2f: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=msr; gold_ct=(MN ^ 1'b1); gold_carry=MC; end
6'h30: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=((IN ^ IV) | IZ); gold_carry=MC; end
6'h31: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=(((IN ^ IV) ^ 1'b1) & (IZ ^ 1'b1)); gold_carry=MC; end
6'h32: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=(IN ^ IV); gold_carry=MC; end
6'h33: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=((IN ^ IV) ^ 1'b1); gold_carry=MC; end
6'h34: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=IZ; gold_carry=MC; end
6'h35: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=(IZ ^ 1'b1); gold_carry=MC; end
6'h36: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=IV; gold_carry=MC; end
6'h37: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=(IV ^ 1'b1); gold_carry=MC; end
6'h38: begin gold_u={IV,IN,(IC ^ 1'b1),IZ}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=status_i; gold_ct=((IC ^ 1'b1) | IZ); gold_carry=(MC ^ 1'b1); end
6'h39: begin gold_u={IV,IN,(IC ^ 1'b1),IZ}; gold_m={IV,IN,(IC ^ 1'b1),IZ}; gold_y=status_i; gold_ct=(IC & (IZ ^ 1'b1)); gold_carry=(MC ^ 1'b1); end
6'h3a: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=IC; gold_carry=MC; end
6'h3b: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=(IC ^ 1'b1); gold_carry=MC; end
6'h3c: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=((IC ^ 1'b1) | IZ); gold_carry=MC; end
6'h3d: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=(IC & (IZ ^ 1'b1)); gold_carry=MC; end
6'h3e: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=IN; gold_carry=MC; end
6'h3f: begin gold_u={IV,IN,IC,IZ}; gold_m={IV,IN,IC,IZ}; gold_y=status_i; gold_ct=(IN ^ 1'b1); gold_carry=MC; end
endcase
if (ceu_n_i) gold_u=usr;
for (integer b=0;b<4;b=b+1) if(cem_n_i || e_n_i[b]) gold_m[b]=msr[b];
case (instruction_i[12:11])
2'd0:gold_carry=0; 2'd1:gold_carry=1; 2'd2:gold_carry=cx_i; default:begin end endcase
if (!se_n_i) begin
case (instruction_i[10:6])
5'h00:begin gold_shift={1'b0,1'b0,1'b0,1'b0}; gold_shift_oe=4'd10;  end
5'h01:begin gold_shift={1'b1,1'b0,1'b1,1'b0}; gold_shift_oe=4'd10;  end
5'h02:begin gold_shift={MN,1'b0,1'b0,1'b0}; gold_shift_oe=4'd10; gold_m[1'b1]=S0; end
5'h03:begin gold_shift={S0,1'b0,1'b1,1'b0}; gold_shift_oe=4'd10;  end
5'h04:begin gold_shift={S0,1'b0,MC,1'b0}; gold_shift_oe=4'd10;  end
5'h05:begin gold_shift={S0,1'b0,MN,1'b0}; gold_shift_oe=4'd10;  end
5'h06:begin gold_shift={S0,1'b0,1'b0,1'b0}; gold_shift_oe=4'd10;  end
5'h07:begin gold_shift={S0,1'b0,1'b0,1'b0}; gold_shift_oe=4'd10; gold_m[1'b1]=Q0; end
5'h08:begin gold_shift={Q0,1'b0,S0,1'b0}; gold_shift_oe=4'd10; gold_m[1'b1]=S0; end
5'h09:begin gold_shift={Q0,1'b0,MC,1'b0}; gold_shift_oe=4'd10; gold_m[1'b1]=S0; end
5'h0a:begin gold_shift={Q0,1'b0,S0,1'b0}; gold_shift_oe=4'd10;  end
5'h0b:begin gold_shift={S0,1'b0,IC,1'b0}; gold_shift_oe=4'd10;  end
5'h0c:begin gold_shift={S0,1'b0,MC,1'b0}; gold_shift_oe=4'd10; gold_m[1'b1]=Q0; end
5'h0d:begin gold_shift={S0,1'b0,Q0,1'b0}; gold_shift_oe=4'd10; gold_m[1'b1]=Q0; end
5'h0e:begin gold_shift={S0,1'b0,(IN ^ IV),1'b0}; gold_shift_oe=4'd10;  end
5'h0f:begin gold_shift={S0,1'b0,Q0,1'b0}; gold_shift_oe=4'd10;  end
5'h10:begin gold_shift={1'b0,1'b0,1'b0,1'b0}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h11:begin gold_shift={1'b0,1'b1,1'b0,1'b1}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h12:begin gold_shift={1'b0,1'b0,1'b0,1'b0}; gold_shift_oe=4'd5;  end
5'h13:begin gold_shift={1'b0,1'b1,1'b0,1'b1}; gold_shift_oe=4'd5;  end
5'h14:begin gold_shift={1'b0,1'b0,1'b0,QN}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h15:begin gold_shift={1'b0,1'b1,1'b0,QN}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h16:begin gold_shift={1'b0,1'b0,1'b0,QN}; gold_shift_oe=4'd5;  end
5'h17:begin gold_shift={1'b0,1'b1,1'b0,QN}; gold_shift_oe=4'd5;  end
5'h18:begin gold_shift={1'b0,QN,1'b0,SN}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h19:begin gold_shift={1'b0,QN,1'b0,MC}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h1a:begin gold_shift={1'b0,QN,1'b0,SN}; gold_shift_oe=4'd5;  end
5'h1b:begin gold_shift={1'b0,1'b0,1'b0,MC}; gold_shift_oe=4'd5;  end
5'h1c:begin gold_shift={1'b0,MC,1'b0,QN}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h1d:begin gold_shift={1'b0,SN,1'b0,QN}; gold_shift_oe=4'd5; gold_m[1'b1]=SN; end
5'h1e:begin gold_shift={1'b0,MC,1'b0,QN}; gold_shift_oe=4'd5;  end
5'h1f:begin gold_shift={1'b0,SN,1'b0,QN}; gold_shift_oe=4'd5;  end
endcase
end
end
