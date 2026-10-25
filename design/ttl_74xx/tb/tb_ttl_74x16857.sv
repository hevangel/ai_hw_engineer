`timescale 1ns/1ps
module tb_ttl_74x16857;
    logic clk,rst_n;
    logic [13:0] d,expected;
    logic [13:0] q;
    ttl_74x16857 dut(.*);
    task automatic check;#1;if(q!==expected) $fatal(1,"register/clock/reset");endtask
    initial begin
        clk=0;rst_n=1;d='1;expected=0;#1;rst_n=0;check;rst_n=1;check;
        for(int i=0;i<512;i++) begin
            d=14'(i*617+91);clk=1;expected=d;check;
            d=~d;check;clk=0;check;
            if(i%7==0) begin rst_n=0;expected=0;check;clk=1;check;clk=0;rst_n=1;check;end
        end
        $display("PASS: tb_ttl_74x16857");$finish;
    end
endmodule
