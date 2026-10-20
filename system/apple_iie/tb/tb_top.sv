`timescale 1ns/1ps
module tb_top;
    logic clk14=0,power_n=0,rst_n=0;
    logic [15:0] a=0;
    logic [7:0] d=0;
    logic we=0; wire bus_clk; wire [7:0] data;
    apple_iie #(.EXTERNAL_CPU(1)) dut(.clk14(clk14),.power_n(power_n),.rst_n(rst_n),
        .external_addr(a),.external_data(d),.external_we(we),.key_data(7'd0),.key_down(1'b0),
        .debug_addr(16'd0),.debug_aux(1'b0),.bus_clk(bus_clk),.bus_data(data));
    always #5 clk14=~clk14;
    task automatic access(input logic [15:0] addr,input bit write_en,input logic [7:0] value,input logic [7:0] expected,input bit check_read);
        a=addr;we=write_en;d=value;@(posedge bus_clk);
        if(check_read && data!==expected)$fatal(1,"Read %h got %h expected %h",addr,data,expected);
        #1;
    endtask
    initial begin
        repeat(8)@(negedge clk14);power_n=1;repeat(56)@(negedge clk14);rst_n=1;
        @(posedge bus_clk);#1;
        access(16'h2000,1,8'ha5,0,0);access(16'h2000,0,0,8'ha5,1);
        access(16'hc005,1,0,0,0);access(16'h2000,1,8'h5a,0,0);
        access(16'hc004,1,0,0,0);access(16'h2000,0,0,8'ha5,1);
        access(16'hc003,1,0,0,0);access(16'h2000,0,0,8'h5a,1);
        access(16'hc002,1,0,0,0);access(16'hc009,1,0,0,0);
        access(16'h0010,1,8'h6e,0,0);access(16'h0010,0,0,8'h6e,1);
        access(16'hc008,1,0,0,0);access(16'h0010,0,0,0,1);
        $display("PASS IIe xezim/Verilator board bus main/aux RAM and ALTZP");$finish;
    end
    initial begin #1000000;$fatal(1,"IIe board timeout");end
endmodule
