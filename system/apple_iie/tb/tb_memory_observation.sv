`timescale 1ns/1ps
module tb_memory_observation;
    logic clk=0,enable=0;logic[16:0] addr=17'h300;wire[7:0] data;
    logic[7:0] fixed_read;
    memory_observation dut(.clk(clk),.write_enable(enable),.write_addr(17'h300),
        .write_data(8'd55),.debug_addr(addr),.debug_data(data));
    initial begin
        #5;enable=1;clk=1;#1;fixed_read=data;
        addr=17'h301;#1;addr=17'h300;#1;
        $display("fixed=%h fresh=%h expected=37",fixed_read,data);
        if(data!==8'h37)$fatal(1,"Fresh read failed");
        if(fixed_read!==8'h37)$fatal(1,"Constant-address asynchronous RAM read is stale");
        $display("PASS asynchronous memory observation");$finish;
    end
endmodule
