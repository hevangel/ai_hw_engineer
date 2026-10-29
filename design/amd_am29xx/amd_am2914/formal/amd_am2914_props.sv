`include "manufacturer_actions.svh"
logic [17:0] golden_actions;
logic [7:0] gold_clear, gold_mask, gold_requests;
logic [2:0] gold_vector, gold_status, gold_held;
logic gold_group, gold_enable, gold_vce, gold_sv, gold_detect, gold_pass, gold_gas;
logic past_valid=0;
always_comb begin
  golden_actions=manufacturer_actions(instruction_i,ie_n_i);
  gold_requests=pending & ~mask;
  // Primary eight-level encoder truth rows, independently of the RTL loop.
  gold_vector=0;
  casez(gold_requests)
    8'b1???????:gold_vector=7;8'b01??????:gold_vector=6;
    8'b001?????:gold_vector=5;8'b0001????:gold_vector=4;
    8'b00001???:gold_vector=3;8'b000001??:gold_vector=2;
    8'b0000001?:gold_vector=1;default:gold_vector=0;
  endcase
  gold_detect=gold_requests!=0;
  gold_pass=gold_detect && !(status>gold_vector) && id_n_i;
  gold_gas=!(golden_actions[13:12]==2 && gold_pass && gold_vector==7);
  gold_clear=0;
  case(golden_actions[9:7])
    1:gold_clear=255;2:gold_clear=m_i;3:gold_clear=mask;
    4:if(vector_clear_enabled)gold_clear=8'd1<<held_vector;
    default:begin end
  endcase
  gold_mask=mask;
  case(golden_actions[2:0])
    1:gold_mask=0;2:gold_mask=255;3:gold_mask=mask & ~m_i;
    4:gold_mask=mask | m_i;5:gold_mask=m_i;default:begin end
  endcase
  gold_status=status;
  case(golden_actions[4:3])
    1:gold_status=0;2:gold_status=ge_n_i ? 3'd0:s_i;
    3:gold_status=gold_pass ? gold_vector+3'd1:3'd0;default:begin end
  endcase
  gold_group=group_n;
  case(golden_actions[6:5])
    1:gold_group=gar_n_i;2:gold_group=ge_n_i;
    3:gold_group=!id_n_i || !gold_gas || (gar_n_i && gold_requests==0);
    default:begin end
  endcase
  gold_enable=request_enabled;
  case(golden_actions[11:10])1:gold_enable=1;2:gold_enable=0;default:begin end endcase
  gold_held=held_vector;gold_vce=vector_clear_enabled;
  case(golden_actions[13:12])
    1:begin gold_held=0;gold_vce=0;end
    2:begin gold_held=gold_vector;gold_vce=gold_pass;end
    default:begin end
  endcase
  gold_sv=overflow_n;
  case(golden_actions[17:16])1:gold_sv=1;2:if(!gold_gas)gold_sv=0;default:begin end endcase
end
always_ff @($global_clock) begin
  past_valid<=1;
  // Native setup/hold: signals may change freely within either CP phase.
  if(past_valid && cp_i!=$past(cp_i))
    assume({p_n_i,m_i,s_i,instruction_i,ie_n_i,lb_i,ge_n_i,gar_n_i,id_n_i}==
           $past({p_n_i,m_i,s_i,instruction_i,ie_n_i,lb_i,ge_n_i,gar_n_i,id_n_i}));
  assert(clear_bits==gold_clear);
  assert(v_o==gold_vector && m_o==mask && s_o==status);
  assert(gs_n_o==group_n && sv_n_o==overflow_n);
  assert(gas_n_o==gold_gas);
  assert(irq_pull_low_o==(gold_pass && request_enabled));
  assert(pd_o==(!group_n || (gold_detect && gold_vector>=status)));
  assert(rd_n_o==(!pd_o && id_n_i));
  assert(m_oe_o==golden_actions[14]);
  assert(s_oe_o==(golden_actions[15] && !group_n));
  assert(v_oe_o==(golden_actions[13:12]==2 && gold_pass));
  for(integer b=0;b<8;b=b+1) begin
    if(!p_n_i[b])assert(pulse[b]);
    else if(lb_i || (!cp_i && gold_clear[b]))assert(!pulse[b]);
    else if(past_valid)assert(pulse[b]==$past(pulse[b]));
  end
  if(!cp_i)assert(edge_data==(pulse & ~gold_clear));
  if(past_valid)begin
    if(cp_i && !$past(cp_i))begin
      assert(pending==$past(pulse & ~gold_clear));
      assert(mask==$past(gold_mask));assert(status==$past(gold_status));
      assert(group_n==$past(gold_group));assert(request_enabled==$past(gold_enable));
      assert(held_vector==$past(gold_held));assert(vector_clear_enabled==$past(gold_vce));
      assert(overflow_n==$past(gold_sv));
    end else begin
      assert({pending,mask,status,group_n,request_enabled,held_vector,vector_clear_enabled,overflow_n}==
             $past({pending,mask,status,group_n,request_enabled,held_vector,vector_clear_enabled,overflow_n}));
    end
  end
  for(integer op=0;op<16;op=op+1)cover(past_valid && cp_i && !$past(cp_i) && !ie_n_i && instruction_i==4'(op));
  cover(past_valid && !lb_i && p_n_i==255 && pulse!=0 && cp_i);
  cover(past_valid && !sv_n_o && !id_n_i);
  cover(past_valid && ie_n_i && irq_pull_low_o);
  cover(past_valid && !ie_n_i && instruction_i==5 && !gar_n_i && !detected);
  cover(past_valid && vector_clear_enabled && vector_code!=held_vector && instruction_i==4);
end
