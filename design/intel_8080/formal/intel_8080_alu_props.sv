`ifdef FORMAL
module intel_8080_alu_props (
    input logic [3:0] kind_i,
    input logic [7:0] lhs_i, rhs_i, flags_i
);
  logic [7:0] value, flags;
  intel_8080_alu dut (.kind_i(kind_i), .lhs_i(lhs_i), .rhs_i(rhs_i),
      .flags_i(flags_i), .value_o(value), .flags_o(flags));
  // Independently derived from pinned external i8080.c helpers, not DUT RTL.
  // Uses signed integer subtraction / XOR carry reconstruction and C-style DAA.
  function automatic logic [15:0] reference_result;
    integer calculation, adjustment, carry_flag, half_flag;
    logic [7:0] result, f;
    logic zsp;
    begin
      calculation=lhs_i; adjustment=0; carry_flag=flags_i[0]; half_flag=flags_i[4];
      result=lhs_i; zsp=0;
      f={flags_i[7:6],1'b0,flags_i[4],1'b0,flags_i[2],1'b1,flags_i[0]};
      case (kind_i)
        0,1: begin
          calculation=int'(lhs_i)+int'(rhs_i)+(kind_i==1 ? int'(flags_i[0]):0);
          carry_flag=(calculation>>8)&1;
          half_flag=((calculation^int'(lhs_i)^int'(rhs_i))>>4)&1; zsp=1;
        end
        2,3,7: begin
          calculation=int'(lhs_i)-int'(rhs_i)-(kind_i==3 ? int'(flags_i[0]):0);
          carry_flag=calculation<0;
          half_flag=((~(calculation^int'(lhs_i)^int'(rhs_i)))>>4)&1; zsp=1;
        end
        4: begin
          calculation=int'(lhs_i)&int'(rhs_i); carry_flag=0;
          // Independent C-oracle i8080_ana; Intel programming manual 1-12.
          half_flag=((int'(lhs_i)|int'(rhs_i))&8)!=0; zsp=1;
        end
        5: begin calculation=int'(lhs_i)^int'(rhs_i); carry_flag=0; half_flag=0; zsp=1; end
        6: begin calculation=int'(lhs_i)|int'(rhs_i); carry_flag=0; half_flag=0; zsp=1; end
        8: begin calculation=int'(lhs_i)+1; half_flag=(calculation&15)==0; zsp=1; end
        9: begin calculation=int'(lhs_i)-1; half_flag=!((calculation&15)==15); zsp=1; end
        10: begin
          if (flags_i[4] || (lhs_i&15)>9) adjustment=6;
          if (flags_i[0] || (lhs_i>>4)>9 || ((lhs_i>>4)>=9 && (lhs_i&15)>9)) begin
            adjustment+=96; carry_flag=1;
          end
          calculation=int'(lhs_i)+adjustment;
          half_flag=((calculation^int'(lhs_i)^adjustment)>>4)&1; zsp=1;
        end
        11: begin calculation=(int'(lhs_i)<<1)|(int'(lhs_i)>>7); carry_flag=lhs_i[7]; end
        12: begin calculation=(int'(lhs_i)>>1)|((int'(lhs_i)&1)<<7); carry_flag=lhs_i[0]; end
        13: begin calculation=(int'(lhs_i)<<1)|int'(flags_i[0]); carry_flag=lhs_i[7]; end
        14: begin calculation=(int'(lhs_i)>>1)|(int'(flags_i[0])<<7); carry_flag=lhs_i[0]; end
        15: calculation=~int'(lhs_i);
      endcase
      result=8'(calculation); f[0]=1'(carry_flag); f[4]=1'(half_flag);
      if (zsp) begin f[7]=result[7]; f[6]=result==0; f[2]=~^result; end
      reference_result={kind_i==7 ? lhs_i : result,f};
    end
  endfunction
  always_comb begin
    assert ({value,flags} == reference_result());
    for (integer kind=0;kind<16;kind++) cover (kind_i==4'(kind));
    cover (kind_i==4 && lhs_i[3] && !rhs_i[3] && flags[4]==1);
    cover (kind_i==4 && !lhs_i[3] && !rhs_i[3] && flags[4]==0);
    cover (kind_i==10 && lhs_i==8'h9a && value==0 && flags[0]);
  end
endmodule
`endif
