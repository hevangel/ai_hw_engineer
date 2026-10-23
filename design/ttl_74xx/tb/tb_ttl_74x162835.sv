`timescale 1ns/1ps
module tb_ttl_74x162835;
    logic clk,le,oe_n,drive;
    logic [17:0] a,y,expected;
    ttl_74x162835 dut(.*);
    task automatic check;
        #1;if(drive!==!oe_n || y!==(oe_n?18'd0:expected)) $fatal(1,"transparency/storage/drive");
    endtask
    initial begin
        clk=0;le=1;oe_n=0;a=0;expected=0;check;
        for(int word_value=0;word_value<128;word_value++) begin
            le=1;#1;
            a=18'(32'hcafe1234^(word_value*32'h01931d21));expected=a;check;
            clk=1;check;
            a=~a;expected=a;check; // transparent even with CLK held high
            le=0;#1;
            a=~a;check;clk=0;check; // falling edge must not capture
            clk=1;expected=a;check;
            a=~a;check; // held high must not be a transparent clock latch
            oe_n=1;check;clk=0;check;clk=1;expected=a;check;oe_n=0;check;
            le=1;#1;a=18'(1) << (word_value%18);expected=a;check;
            clk=0;check;
        end
        $display("PASS: tb_ttl_74x162835");$finish;
    end
endmodule
