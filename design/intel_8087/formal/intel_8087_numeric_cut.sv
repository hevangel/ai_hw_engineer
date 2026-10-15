// Arithmetic is unconstrained at the controller proof boundary.
module intel_8087_alu(input [79:0] a_i,b_i,input [3:0] op_i,input [15:0] control_i,
    output [79:0] result_o,output [5:0] exceptions_o,output rounded_up_o,output [3:0] condition_o);
    (* anyseq *) logic [90:0] response;
    assign {result_o,exceptions_o,rounded_up_o,condition_o}=response;
endmodule
module intel_8087_trans(input clk,rst_n,start_i,input [2:0] op_i,input [79:0] x_i,y_i,
    output logic done_o,output [79:0] result_o);
    (* anyseq *) logic [79:0] response;
    assign result_o=response;
    always_ff @(posedge clk) if(!rst_n) done_o<=0;else done_o<=start_i;
endmodule
