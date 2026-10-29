// Included inside the native slice only for formal verification.
`ifdef FORMAL
  (* anyconst *) logic [3:0] watch_address;
  logic formal_past_valid=0;
  logic formal_written=0;
  logic formal_unrelated=0;
  always_ff @($global_clock) begin
    assume(storage_write_data==ram_input);
    formal_past_valid<=1;
    // Legal source transitions: stable inputs across the actual clock edge.
    // They remain unconstrained throughout either transparent phase.
    if (formal_past_valid && cp_i!=$past(cp_i))
      assume({instruction_i,a_i,b_i,d_i,cn_i,oe_n_i,ram0_i,ram3_i,q0_i,q3_i}==
             $past({instruction_i,a_i,b_i,d_i,cn_i,oe_n_i,ram0_i,ram3_i,q0_i,q3_i}));
    assert(y_oe_o==!oe_n_i);
    assert(ram0_oe_o==(dest==4 || dest==5));
    assert(ram3_oe_o==(dest==6 || dest==7));
    assert(q0_oe_o==(dest==4) && q3_oe_o==(dest==6));
    if (cp_i) assert(a_latch==memory[a_i] && b_latch==memory[b_i]);
    if (!cp_i && dest>=2 && b_i==watch_address) begin
      assert(memory[watch_address]==ram_input);
      formal_written<=1;
    end
    if (formal_past_valid) begin
      if (!cp_i && !$past(cp_i)) assert({a_latch,b_latch}==$past({a_latch,b_latch}));
      if (cp_i==$past(cp_i)) assert(q==$past(q));
      if (cp_i || dest<2 || b_i!=watch_address) assert(memory[watch_address]==$past(memory[watch_address]));
      if (cp_i && !$past(cp_i)) begin
        case ($past(dest))
          0: assert(q==$past(f));
          4: assert(q=={$past(q3_i),$past(q[3:1])});
          6: assert(q=={$past(q[2:0]),$past(q0_i)});
          default: assert(q==$past(q));
        endcase
      end
    end
    if (formal_written && !cp_i && dest>=2 && b_i!=watch_address) formal_unrelated<=1;
    cover(formal_written && formal_unrelated && cp_i && a_i==watch_address && y_o==4'ha && dest==1 && instruction_i[5:0]==4);
    cover(formal_past_valid && cp_i && !$past(cp_i) && dest==0 && q==4'h5);
    cover(formal_past_valid && cp_i && !$past(cp_i) && dest==4 && q==4'h8);
    cover(formal_past_valid && cp_i && !$past(cp_i) && dest==6 && q==4'h3);
    cover(!oe_n_i && dest==2 && y_o!=f);
  end
`endif
