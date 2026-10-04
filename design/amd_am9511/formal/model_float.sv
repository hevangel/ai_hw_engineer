// Transport-only abstraction: unconstrained numerical result/status, two-cycle response.
module amd_am9511_float(input logic clk_i,reset_i,start_i,input logic [4:0] operation_i,
 input logic [31:0] a_i,b_i,output logic float_result_o,single_result_o,
 output logic busy_o,done_o,output logic [31:0] result_o,output logic [6:0] status_o);
 logic [1:0] phase;
 (* anyseq *) logic [31:0] value;
 (* anyseq *) logic [6:0] flags;
 assign result_o=value;assign status_o=flags;
 assign busy_o=phase!=0;assign done_o=phase==2;
 (* anyseq *) logic format; assign float_result_o=format;assign single_result_o=!format;
 always_ff @(posedge clk_i)begin
 if(reset_i)phase<=0;
 else if(phase==0)begin if(start_i)phase<=1;end
 else if(phase==1)phase<=2;
 else phase<=0;
 end
endmodule
