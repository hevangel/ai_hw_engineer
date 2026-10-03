`ifdef FORMAL
  (* anyconst *) logic [1:0] watch_slot;
  logic past_valid=0;
  always_ff @(posedge cp_i) begin
    past_valid<=1;
    assert(y_oe_o==!oe_n_i);
    assert(cn4_o==(cn_i && &y_o));
    if (!zero_n_i) assert(y_o==0);
    else assert(y_o==(selected_address|or_i));
    if (past_valid) begin
      assert(upc==$past(y_o)+4'($past(cn_i)));
      assert(address_register==($past(re_n_i) ? $past(address_register):$past(r_i)));
      if ($past(fe_n_i)) assert(sp==$past(sp));
      else assert(sp==($past(push_i) ? $past(sp)+2'd1:$past(sp)-2'd1));
      if (!$past(fe_n_i) && $past(push_i) && watch_slot==$past(next_sp))
        assert(stack[watch_slot]==$past(upc));
      else assert(stack[watch_slot]==$past(stack[watch_slot]));
    end
    for (int source=0;source<4;source++) cover(past_valid && select_i==2'(source) && y_o==4'ha && zero_n_i && or_i==0);
    cover(past_valid && !fe_n_i && push_i && sp==3 && upc!=y_o);
    cover(past_valid && !fe_n_i && !push_i && sp==0);
    cover(past_valid && !cn_i && select_i==0 && zero_n_i && or_i==0);
    cover(past_valid && !zero_n_i && or_i==15 && !oe_n_i && y_o==0);
    cover(past_valid && cn4_o && oe_n_i);
  end
`endif
