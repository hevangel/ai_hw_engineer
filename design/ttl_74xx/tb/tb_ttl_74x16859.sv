`timescale 1ns/1ps
module tb_ttl_74x16859;
    logic clk,rst_n;
    logic [12:0] d,expected;
    logic [12:0] q_a,q_b;
    ttl_74x16859 dut(.*);
    task automatic check;#1;if(q_a!==expected || q_b!==expected) $fatal(1,"register/clock/reset");endtask
    initial begin
        clk=0;rst_n=1;d='1;expected=0;#1;rst_n=0;check;rst_n=1;check;
        for(int i=0;i<512;i++) begin
            d=13'(i*617+91);clk=1;expected=d;check;
            d=~d;check;clk=0;check;
            if(i%7==0) begin rst_n=0;expected=0;check;clk=1;check;clk=0;rst_n=1;check;end
        end
        $display("PASS: tb_ttl_74x16859");$finish;
    end
endmodule
