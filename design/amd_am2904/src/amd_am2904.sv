module amd_am2904 (
  input logic cp_i,
  input logic [12:0] instruction_i,
  input logic [3:0] status_i, y_i, shift_i,
  input logic cx_i, ceu_n_i, cem_n_i,
  input logic [3:0] e_n_i,
  input logic oey_n_i, oect_n_i, se_n_i,
  output logic [3:0] y_o, shift_o, shift_oe_o,
  output logic y_oe_o, ct_o, ct_oe_o, carry_o
);
  // Native status order {overflow,negative,carry,zero}; no hardware reset.
  logic [3:0] usr, msr, u_load, m_load, u_next, m_next, selected;
  logic shift_carry_load, shift_carry, signed_less;
  // ASSUMPTION: settled digital pin values; external wiring resolves the
  // separate value/enable ports. Released shift values are represented as 0.
  always_comb begin
    u_load=status_i;
    m_load=status_i;
    case(instruction_i[5:0])
      6'o00:begin u_load=msr; m_load=y_i; end
      6'o01:begin u_load=4'hf; m_load=4'hf; end
      6'o02:begin u_load=msr; m_load=usr; end
      6'o03:begin u_load=0; m_load=0; end
      6'o04:begin m_load[1]=msr[3]; m_load[3]=msr[1]; end
      6'o05:m_load=~msr;
      6'o06,6'o07:u_load[3]=status_i[3]|usr[3];
      6'o10,6'o11:begin u_load=usr; u_load[0]=instruction_i[0]; m_load[1]=~status_i[1]; end
      6'o12,6'o13:begin u_load=usr; u_load[1]=instruction_i[0]; end
      6'o14,6'o15:begin u_load=usr; u_load[2]=instruction_i[0]; end
      6'o16,6'o17:begin u_load=usr; u_load[3]=instruction_i[0]; end
      6'o30,6'o31,6'o50,6'o51,6'o70,6'o71:begin
        u_load[1]=~status_i[1]; m_load[1]=~status_i[1];
      end
      default:begin end
    endcase
    u_next=ceu_n_i ? usr : u_load;
    for(integer b=0;b<4;b=b+1)
      m_next[b]=(cem_n_i || e_n_i[b]) ? msr[b] : m_load[b];
    // Table7 notes2/3 override BOTH machine carry enables on a shift load.
    if(!se_n_i && shift_carry_load) m_next[1]=shift_carry;
  end
  always_ff @(posedge cp_i) begin usr<=u_next; msr<=m_next; end

  always_comb begin
    case(instruction_i[5:4])
      2'd0,2'd1:selected=usr;
      2'd2:selected=msr;
      default:selected=status_i;
    endcase
    y_o=selected;
    y_oe_o=!oey_n_i && instruction_i[5:0]!=0;
    ct_oe_o=!oect_n_i;
    signed_less=selected[2]^selected[3];
    case(instruction_i[3:0])
      4'h0:ct_o=signed_less|selected[0];
      4'h1:ct_o=~signed_less & ~selected[0];
      4'h2:ct_o=signed_less;
      4'h3:ct_o=~signed_less;
      4'h4:ct_o=selected[0];
      4'h5:ct_o=~selected[0];
      4'h6:ct_o=selected[3];
      4'h7:ct_o=~selected[3];
      4'h8:ct_o=(selected[1]^instruction_i[4])|selected[0];
      4'h9:ct_o=~(selected[1]^instruction_i[4]) & ~selected[0];
      4'ha:ct_o=selected[1];
      4'hb:ct_o=~selected[1];
      4'hc:ct_o=~selected[1]|selected[0];
      4'hd:ct_o=selected[1] & ~selected[0];
      4'he:ct_o=instruction_i[5:4]==0 ? status_i[2]^msr[2] : selected[2];
      default:ct_o=instruction_i[5:4]==0 ? ~(status_i[2]^msr[2]) : ~selected[2];
    endcase
    case(instruction_i[12:11])
      2'd0:carry_o=0;
      2'd1:carry_o=1;
      2'd2:carry_o=cx_i;
      default:carry_o=(instruction_i[5] ? msr[1] : usr[1]) ^
                      (instruction_i[3:1]==3'b100);
    endcase
  end
  always_comb begin
    shift_o=0;
    shift_oe_o=0;
    shift_carry_load=0;
    shift_carry=0;
    if(!instruction_i[10]) begin
      case(instruction_i[9:6])
        4'h0:begin shift_o[1]=0; shift_o[3]=0; end
        4'h1:begin shift_o[1]=1; shift_o[3]=1; end
        4'h2:begin shift_o[1]=0; shift_o[3]=msr[2]; shift_carry_load=1; shift_carry=shift_i[0]; end
        4'h3:begin shift_o[1]=1; shift_o[3]=shift_i[0]; end
        4'h4:begin shift_o[1]=msr[1]; shift_o[3]=shift_i[0]; end
        4'h5:begin shift_o[1]=msr[2]; shift_o[3]=shift_i[0]; end
        4'h6,4'h7:begin shift_o[1]=0; shift_o[3]=shift_i[0]; shift_carry_load=instruction_i[6]; shift_carry=shift_i[2]; end
        4'h8:begin shift_o[1]=shift_i[0]; shift_o[3]=shift_i[2]; shift_carry_load=1; shift_carry=shift_i[0]; end
        4'h9:begin shift_o[1]=msr[1]; shift_o[3]=shift_i[2]; shift_carry_load=1; shift_carry=shift_i[0]; end
        4'ha:begin shift_o[1]=shift_i[0]; shift_o[3]=shift_i[2]; end
        4'hb:begin shift_o[1]=status_i[1]; shift_o[3]=shift_i[0]; end
        4'hc:begin shift_o[1]=msr[1]; shift_o[3]=shift_i[0]; shift_carry_load=1; shift_carry=shift_i[2]; end
        4'hd:begin shift_o[1]=shift_i[2]; shift_o[3]=shift_i[0]; shift_carry_load=1; shift_carry=shift_i[2]; end
        4'he:begin shift_o[1]=status_i[2]^status_i[3]; shift_o[3]=shift_i[0]; end
        default:begin shift_o[1]=shift_i[2]; shift_o[3]=shift_i[0]; end
      endcase
      if(!se_n_i) shift_oe_o=4'b1010;
    end else begin
      case(instruction_i[9:6])
        4'h0,4'h1:begin shift_o[0]=instruction_i[6]; shift_o[2]=instruction_i[6]; shift_carry_load=1; shift_carry=shift_i[1]; end
        4'h2,4'h3:begin shift_o[0]=instruction_i[6]; shift_o[2]=instruction_i[6]; end
        4'h4,4'h5:begin shift_o[0]=shift_i[3]; shift_o[2]=instruction_i[6]; shift_carry_load=1; shift_carry=shift_i[1]; end
        4'h6,4'h7:begin shift_o[0]=shift_i[3]; shift_o[2]=instruction_i[6]; end
        4'h8:begin shift_o[0]=shift_i[1]; shift_o[2]=shift_i[3]; shift_carry_load=1; shift_carry=shift_i[1]; end
        4'h9:begin shift_o[0]=msr[1]; shift_o[2]=shift_i[3]; shift_carry_load=1; shift_carry=shift_i[1]; end
        4'ha:begin shift_o[0]=shift_i[1]; shift_o[2]=shift_i[3]; end
        4'hb:begin shift_o[0]=msr[1]; shift_o[2]=0; end
        4'hc:begin shift_o[0]=shift_i[3]; shift_o[2]=msr[1]; shift_carry_load=1; shift_carry=shift_i[1]; end
        4'hd:begin shift_o[0]=shift_i[3]; shift_o[2]=shift_i[1]; shift_carry_load=1; shift_carry=shift_i[1]; end
        4'he:begin shift_o[0]=shift_i[3]; shift_o[2]=msr[1]; end
        default:begin shift_o[0]=shift_i[3]; shift_o[2]=shift_i[1]; end
      endcase
      if(!se_n_i) shift_oe_o=4'b0101;
    end
    if(se_n_i)shift_o=0;
  end
`ifdef FORMAL
  `include "amd_am2904_props.sv"
`endif
endmodule
