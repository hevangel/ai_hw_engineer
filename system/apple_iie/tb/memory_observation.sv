`timescale 1ns/1ps
// Isolated language-level diagnostic, not a replacement platform memory.
module memory_observation(input logic clk,write_enable,input logic[16:0] write_addr,
    input logic[7:0] write_data,input logic[16:0] debug_addr,output logic[7:0] debug_data);
    logic[7:0] ram[0:131071];
    initial for(int i=0;i<131072;i++)ram[i]=0;
    always_ff @(posedge clk)if(write_enable)ram[write_addr]<=write_data;
    assign debug_data=ram[debug_addr];
endmodule
