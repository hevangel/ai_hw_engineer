`include "manufacturer_oracle.svh"
logic past_valid=0;
always_ff @(posedge cp_i) begin
  past_valid<=1;
  assert(y_o==gold_y);
  assert(y_oe_o==gold_y_oe);
  assert(ct_o==gold_ct);
  assert(ct_oe_o==gold_ct_oe);
  assert(carry_o==gold_carry);
  assert(shift_o==gold_shift);
  assert(shift_oe_o==gold_shift_oe);
  if(past_valid) begin
    assert(usr==$past(gold_u));
    assert(msr==$past(gold_m));
  end
  for(integer op=0;op<32;op=op+1)
    cover(past_valid && !se_n_i && instruction_i[10:6]==5'(op));
  cover(past_valid && !ceu_n_i && !cem_n_i && e_n_i==0 && instruction_i[5:0]==2 && usr!=msr);
  cover(past_valid && instruction_i[5:0]==0 && !ceu_n_i && !cem_n_i && y_i!=msr);
  cover(past_valid && instruction_i[5:0]==6 && usr[3] && !status_i[3] && !ceu_n_i);
  cover(past_valid && !se_n_i && instruction_i[10:6]==2 && cem_n_i && e_n_i[1] && shift_i[0]!=msr[1]);
end
