`timescale 1ns/1ps
// Internal bit-serial unsigned remainder for full native-float angle reduction.
// Input is magnitude in Q112. 176 clocks avoid a large combinational modulo.
module amd_am9511_phase_reducer (
 input logic clk_i,reset_i,start_i,
 input logic [175:0] value_i,
 input logic [114:0] modulus_i,
 output logic busy_o,done_o,
 output logic [63:0] phase_q56_o
);
 localparam logic [1:0] IDLE=0,RUN=1,COMPLETE=2;
 logic [1:0] state;
 logic [7:0] remaining;
 logic [175:0] value_q;
 logic [114:0] remainder_q,modulus_q,next_remainder;
 logic [115:0] trial;
 always_comb begin
  trial={remainder_q,value_q[175]};next_remainder=trial[114:0];
  if(trial>={1'b0,modulus_q})next_remainder=115'(trial-{1'b0,modulus_q});
 end
 assign busy_o=state!=IDLE;
 assign done_o=state==COMPLETE;
 always_ff @(posedge clk_i)begin
  if(reset_i)begin state<=IDLE;remaining<=0;value_q<=0;remainder_q<=0;modulus_q<=0;phase_q56_o<=0;end
  else case(state)
   IDLE:if(start_i)begin value_q<=value_i;modulus_q<=modulus_i;remainder_q<=0;remaining<=176;state<=RUN;end
   RUN:begin
    remainder_q<=next_remainder;value_q<=value_q<<1;remaining<=remaining-8'd1;
    if(remaining==1)begin phase_q56_o<={5'd0,next_remainder[114:56]};state<=COMPLETE;end
   end
   COMPLETE:state<=IDLE;
   default:state<=IDLE;
  endcase
 end
endmodule
