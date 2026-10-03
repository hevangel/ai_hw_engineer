(* anyconst *) logic [3:0] watch_address;
logic past_valid=0;
logic written=0;
always_ff @($global_clock) begin
  assume(storage_write_data==ram_input);
  past_valid<=1;
  if(past_valid && cp_i!=$past(cp_i))
    assume({instruction_i,a_i,b_i,da_i,db_i,y_i,ea_i,oe_b_n_i,oe_y_n_i,we_n_i,ien_n_i,cn_i,lss_n_i,mss_n_i,z_i,sio0_i,sio3_i,qio0_i,qio3_i}==
      $past({instruction_i,a_i,b_i,da_i,db_i,y_i,ea_i,oe_b_n_i,oe_y_n_i,we_n_i,ien_n_i,cn_i,lss_n_i,mss_n_i,z_i,sio0_i,sio3_i,qio0_i,qio3_i}));
  assert(y_oe_o==!oe_y_n_i && db_oe_o==!oe_b_n_i && write_oe_o==!lss_n_i);
  assert(r==(ea_i ? da_i:a_latch));
  assert(s==(instruction_i[0] ? q:oe_b_n_i ? db_i:b_latch));
  if(cp_i) assert(a_latch==memory[a_i] && b_latch==memory[b_i]);
  if(!cp_i && !we_n_i && b_i==watch_address) begin
    assert(memory[watch_address]==ram_input);written<=1;
  end
  if(past_valid) begin
    if(!cp_i && !$past(cp_i)) assert({a_latch,b_latch}==$past({a_latch,b_latch}));
    if(cp_i || we_n_i || b_i!=watch_address) assert(memory[watch_address]==$past(memory[watch_address]));
    if(cp_i && !$past(cp_i)) begin
      assert(q==($past(q_enable) ? $past(q_next):$past(q)));
      assert(sc==($past(sc_enable) ? $past(sc_next):$past(sc)));
    end else assert({q,sc}==$past({q,sc}));
  end
  cover(written && cp_i && b_i==watch_address && db_o==10);
  cover(past_valid && cp_i && !$past(cp_i) && q_enable && q==5);
  cover(past_valid && cp_i && !$past(cp_i) && sc_enable && sc);
  cover(!cp_i && !we_n_i && ien_n_i && oe_y_n_i && ram_input==9);
  cover(ien_n_i && !lss_n_i && write_n_o);
end
