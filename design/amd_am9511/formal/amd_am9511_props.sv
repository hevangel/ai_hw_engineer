// Numerical units are abstracted ONLY in the transport proof configuration.
`include "documented_stack.svh"
logic formal_past=0;
logic [255:0] formal_stack;
logic [6:0] formal_mask,formal_result_flags;
logic [31:0] formal_result;
logic formal_finish;
always_comb begin
 formal_finish=(state==LAUNCH&&descriptor[11:10]==0)||(state==FIXED_WAIT&&fixed_done)||(state==FLOAT_WAIT&&float_done)||(state==DERIVED_WAIT&&derived_done);
 formal_result=state==FIXED_WAIT?fixed_result:state==FLOAT_WAIT?float_result:state==DERIVED_WAIT?derived_result:32'd0;
 formal_result_flags=state==FIXED_WAIT?fixed_flags:state==FLOAT_WAIT?float_flags:state==DERIVED_WAIT?derived_flags:local_flags;
 formal_stack=documented_stack(command_q[6:0],stack_q,formal_result,float_format);
 formal_mask=documented_flags(command_q[6:0]);
end
always_ff @(posedge clk_i)begin
 formal_past<=1;
 if(!formal_past)assume(reset_i);
 assume(rd_n_i||wr_n_i);
 if(formal_past)begin
  assert(state<=DERIVED_WAIT);
  assert(data_oe_o==(!cs_n_i&&!rd_n_i));
  assert(pause_n_o==(!active||cycle_done));
  assert(!svreq_o||svack_n_i);
  if($past(reset_i))begin
   assert(state==IDLE&&status_q==0&&!cycle_done&&!end_pending&&!service_pending);
   assert(stack_q==$past(stack_q));
  end else begin
   if($past(formal_finish))begin
    assert(state==IDLE&&completion_pulse);
    assert((stack_q&$past(formal_stack[255:128]))==($past(formal_stack[127:0])&$past(formal_stack[255:128])));
    assert(status_q==(($past(status_q)&~$past(formal_mask))|($past(formal_result_flags)&$past(formal_mask))));
    assert(service_pending==($past(command_q[7])&&$past(svack_n_i)));
   end else begin
    assert(status_q==$past(status_q));
    if($past(active&&!cycle_done&&state==IDLE&&!cd_i))begin
     if($past(wr_n_i))assert(stack_q=={$past(stack_q[119:0]),$past(stack_q[127:120])});
     else assert(stack_q=={$past(data_i),$past(stack_q[127:8])});
    end else assert(stack_q==$past(stack_q));
   end
   if($past(active&&!cycle_done&&(status_read||state==IDLE)))begin
    assert(cycle_done);
    if($past(!rd_n_i))begin
     if($past(cd_i))assert(read_latch=={$past(state!=IDLE),$past(status_q)});
     else assert(read_latch==$past(stack_q[127:120]));
    end
   end else assert(read_latch==$past(read_latch));
   if($past(active&&cycle_done))assert(cycle_done&&command_q==$past(command_q));
   if($past(!active))assert(!cycle_done);
   if($past(!svack_n_i)&&!$past(formal_finish))assert(!service_pending);
   if($past(!eack_n_i||active&&!cycle_done)&&!$past(formal_finish))assert(!end_pending);
  end
 end
 cover(formal_past&&state!=IDLE&&active&&!cd_i&&!cycle_done);
 cover(formal_past&&state!=IDLE&&status_read&&cycle_done);
 cover(formal_past&&completion_pulse&&!eack_n_i);
 cover(formal_past&&service_pending&&!svack_n_i);
 cover(formal_past&&reset_i&&stack_q!=0);
 cover(formal_past&&active&&cycle_done&&!rd_n_i&&read_latch!=0);
end
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h00);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h01);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h02);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h03);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h04);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h05);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h06);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h07);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h08);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h09);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h0a);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h0b);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h10);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h11);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h12);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h13);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h15);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h17);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h18);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h19);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h1a);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h1c);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h1d);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h1e);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h1f);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h2c);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h2d);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h2e);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h2f);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h34);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h36);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h37);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h38);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h39);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h6c);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h6d);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h6e);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h6f);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h74);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h76);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h77);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h78);
always_ff @(posedge clk_i)cover(formal_past&&completion_pulse&&command_q[6:0]==7'h79);
