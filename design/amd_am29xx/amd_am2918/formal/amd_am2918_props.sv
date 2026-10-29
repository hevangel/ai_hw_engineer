// Manufacturer truth table PDF211: native rising capture and all other holds.
logic past_valid=0;
always_ff @($global_clock)begin
  past_valid<=1;
  if(past_valid && cp_i!=$past(cp_i))assume(d_i==$past(d_i));
  assert(y_o==q_o);
  assert(y_oe_o==!oe_n_i);
  if(past_valid)begin
    if(cp_i && !$past(cp_i))assert(q_o==$past(d_i));
    else assert(q_o==$past(q_o));
  end
  cover(past_valid && cp_i && !$past(cp_i) && oe_n_i && q_o==10);
  cover(past_valid && cp_i && !$past(cp_i) && !oe_n_i && y_o==5);
  cover(past_valid && !cp_i && $past(cp_i) && q_o==3);
  cover(past_valid && cp_i==$past(cp_i) && oe_n_i!=$past(oe_n_i) && q_o==15);
end
