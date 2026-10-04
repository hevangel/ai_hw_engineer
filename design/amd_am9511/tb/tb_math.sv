`timescale 1ns/1ps
module tb_math(input logic clk_i,reset_i,start_i,signed_i,
 input logic [127:0] numerator_i,input logic [63:0] denominator_i,
 input logic [175:0] value_i,input logic [114:0] modulus_i,
 output logic divide_busy_o,divide_done_o,zero_o,phase_busy_o,phase_done_o,
 output logic [127:0] quotient_o,output logic [63:0] remainder_o,phase_o);
 amd_am9511_divider divider(.clk_i(clk_i),.reset_i(reset_i),.start_i(start_i),.signed_i(signed_i),
 .numerator_i(numerator_i),.denominator_i(denominator_i),.busy_o(divide_busy_o),.done_o(divide_done_o),
 .zero_o(zero_o),.quotient_o(quotient_o),.remainder_o(remainder_o));
 amd_am9511_phase_reducer phase(.clk_i(clk_i),.reset_i(reset_i),.start_i(start_i),
 .value_i(value_i),.modulus_i(modulus_i),.busy_o(phase_busy_o),.done_o(phase_done_o),.phase_q56_o(phase_o));
endmodule
