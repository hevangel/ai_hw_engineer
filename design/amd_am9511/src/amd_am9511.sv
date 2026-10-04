`timescale 1ns/1ps
// Original Am9511 functional command/stack reconstruction. See spec/spec.md
// for the explicit clock-sampled interface and approximation contract.
module amd_am9511 (
 input logic clk_i,reset_i,cs_n_i,rd_n_i,wr_n_i,cd_i,eack_n_i,svack_n_i,
 input logic [7:0] data_i,
 output logic [7:0] data_o,
 output logic data_oe_o,pause_n_o,end_pull_low_o,svreq_o
);
`include "amd_am9511_commands.svh"
 localparam logic [2:0] IDLE=0,LAUNCH=1,FIXED_WAIT=2,FLOAT_WAIT=3,DERIVED_WAIT=4;
 logic [2:0] state;
 logic [127:0] stack_q,local_stack;
 logic [7:0] command_q,read_latch;
 logic [6:0] status_q,local_flags;
 logic [11:0] descriptor;
 logic cycle_done,active,status_read,end_pending,completion_pulse,service_pending,local_zero;
 logic fixed_start,float_start,derived_start,fixed_done,float_done,derived_done;
 logic unused_fixed_busy,unused_float_busy,unused_derived_busy,unused_fixed_defined,unused_single_format;
 logic [31:0] fixed_result,float_result,derived_result;
 logic [6:0] fixed_flags,float_flags,derived_flags;
 logic float_format;
 assign descriptor=command_descriptor(command_q[6:0]);
 assign active=!cs_n_i&&(rd_n_i^wr_n_i);
 assign status_read=active&&!rd_n_i&&cd_i;
 assign data_oe_o=!cs_n_i&&!rd_n_i;
 assign data_o=read_latch;
 assign pause_n_o=!(active&&!cycle_done);
 // ASSUMPTION: acknowledgments are sampled; tied-LOW EACK completion is
 // exposed for the HIGH clock phase, shorter than one complete period.
 assign end_pull_low_o=(end_pending&&eack_n_i)||(completion_pulse&&clk_i);
 assign svreq_o=service_pending&&svack_n_i;
 assign fixed_start=state==LAUNCH&&descriptor[11:10]==1;
 assign float_start=state==LAUNCH&&descriptor[11:10]==2;
 assign derived_start=state==LAUNCH&&descriptor[11:10]==3;
 amd_am9511_fixed fixed_unit(.clk_i(clk_i),.reset_i(reset_i),.start_i(fixed_start),
  .single_i(command_q[6]),.operation_i(descriptor[9:7]),
  .a_i(command_q[6]?{16'd0,stack_q[127:112]}:stack_q[127:96]),
  .b_i(command_q[6]?{16'd0,stack_q[111:96]}:stack_q[95:64]),
  .busy_o(unused_fixed_busy),.done_o(fixed_done),.result_o(fixed_result),
  .status_o(fixed_flags),.result_defined_o(unused_fixed_defined));
 amd_am9511_float float_unit(.clk_i(clk_i),.reset_i(reset_i),.start_i(float_start),
  .operation_i(command_q[4:0]),
  .a_i(command_q[6:0]==7'h1d ? {16'd0,stack_q[127:112]}:stack_q[127:96]),.b_i(stack_q[95:64]),
  .busy_o(unused_float_busy),.done_o(float_done),.result_o(float_result),.status_o(float_flags),
  .float_result_o(float_format),.single_result_o(unused_single_format));
 amd_am9511_derived derived_unit(.clk_i(clk_i),.reset_i(reset_i),.start_i(derived_start),
  .operation_i(command_q[3:0]),.a_i(stack_q[127:96]),.b_i(stack_q[95:64]),
  .busy_o(unused_derived_busy),.done_o(derived_done),.result_o(derived_result),.status_o(derived_flags));
 always_comb begin
  local_stack=stack_q;
  case(command_q[6:0])
   7'h15:if(stack_q[119])local_stack[127]=!stack_q[127];
   7'h17,7'h37:local_stack={stack_q[127:96],stack_q[127:32]};
   7'h77:local_stack={stack_q[127:112],stack_q[127:16]};
   7'h18,7'h38:local_stack={stack_q[95:0],stack_q[127:96]};
   7'h78:local_stack={stack_q[111:0],stack_q[127:112]};
   7'h19,7'h39:local_stack={stack_q[95:64],stack_q[127:96],stack_q[63:0]};
   7'h79:local_stack={stack_q[111:96],stack_q[127:112],stack_q[95:0]};
   // ASSUMPTION: native PUPI bits are pinned by the external emulator.
   7'h1a:local_stack={32'h02c90fda,stack_q[127:32]};
   default:begin end
  endcase
  local_zero=command_q[5]?(command_q[6]?local_stack[127:112]==0:local_stack[127:96]==0):!local_stack[119];
  local_flags=command_q[6:0]==0?7'd0:{local_stack[127],local_zero,5'd0};
 end
 task automatic finish(input logic [127:0] new_stack,input logic [6:0] flags);
  stack_q<=new_stack;
  // ASSUMPTION: fields outside AMD's explicit affected list hold.
  status_q<=(status_q&~descriptor[6:0])|(flags&descriptor[6:0]);
  state<=IDLE;completion_pulse<=1;end_pending<=1;service_pending<=command_q[7]&&svack_n_i;
 endtask
 always_ff @(posedge clk_i)begin
  if(reset_i)begin
   state<=IDLE;command_q<=0;status_q<=0;cycle_done<=0;read_latch<=0;
   end_pending<=0;completion_pulse<=0;service_pending<=0;
   // Native RESET leaves the entire data stack untouched.
  end else begin
   completion_pulse<=0;
   if(!eack_n_i)end_pending<=0;
   if(!svack_n_i)service_pending<=0;
   case(state)
    LAUNCH:case(descriptor[11:10])
     0:finish(local_stack,local_flags);
     1:state<=FIXED_WAIT;
     2:state<=FLOAT_WAIT;
     3:state<=DERIVED_WAIT;
    endcase
    FIXED_WAIT:if(fixed_done)begin
     if(descriptor[9:7]==5)begin
      if(command_q[6])finish({fixed_result[15:0],stack_q[111:0]},fixed_flags);
      else finish({fixed_result,stack_q[95:0]},fixed_flags);
     end else if(command_q[6])
      finish({fixed_result[15:0],stack_q[95:0],descriptor[9:7]<=1?stack_q[127:112]:16'd0},fixed_flags);
     else finish({fixed_result,stack_q[63:0],descriptor[9:7]<=1?stack_q[127:96]:32'd0},fixed_flags);
    end
    FLOAT_WAIT:if(float_done)begin
     case(command_q[6:0])
      7'h1d:finish({float_result,stack_q[111:48],32'd0},float_flags);
      7'h1f:begin
       if(float_format)finish({stack_q[127:32],32'd0},float_flags);
       else finish({float_result[15:0],stack_q[95:32],48'd0},float_flags);
      end
      7'h1c,7'h1e:finish({float_result,stack_q[95:32],32'd0},float_flags);
      default:finish({float_result,stack_q[63:0],32'd0},float_flags);
     endcase
    end
    DERIVED_WAIT:if(derived_done)begin
     case(command_q[3:0])
      1:finish({derived_result,stack_q[95:32],32'd0},derived_flags);
      5,6:finish({derived_result,96'd0},derived_flags);
      11:finish({derived_result,stack_q[63:32],64'd0},derived_flags);
      default:finish({derived_result,stack_q[95:64],64'd0},derived_flags);
     endcase
    end
    default:begin end
   endcase
   // ASSUMPTION: sampled host cycles complete once and are held until release.
   if(!active)cycle_done<=0;
   if(active&&!cycle_done)begin
    end_pending<=0;
    if(status_read||state==IDLE)begin
     cycle_done<=1;
     if(!rd_n_i)begin
      if(cd_i)read_latch<={state!=IDLE,status_q};
      else begin read_latch<=stack_q[127:120];stack_q<={stack_q[119:0],stack_q[127:120]};end
     end else if(cd_i)begin command_q<=data_i;state<=LAUNCH;end
     else stack_q<={data_i,stack_q[127:8]};
    end
   end
  end
 end
`ifdef AM9511_TRANSPORT_FORMAL
`include "amd_am9511_props.sv"
`endif
endmodule
