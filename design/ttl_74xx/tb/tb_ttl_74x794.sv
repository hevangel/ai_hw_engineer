`timescale 1ns/1ps
module tb_ttl_74x794;
    logic [7:0] d_in,q,d_out,expected;
    logic clk,oe_n,d_drive;
    ttl_74x794 dut(.*);
    task automatic check;
        #1;
        if(q!==expected || d_drive!==!oe_n || d_out!==(!oe_n?expected:8'd0))
            $fatal(1,"dedicated Q and readback bus");
    endtask
    initial begin
        clk=0;oe_n=1;d_in=0;expected=0;clk=0;#1;clk=1;#1;check;clk=0;#1;
        for(int pattern=0;pattern<256;pattern++) begin
            oe_n=1;d_in=8'(pattern);clk=0;#1;clk=1;#1;expected=d_in;check;
            clk=0;#1;d_in=~d_in;check;
            oe_n=0;check;
            d_in=8'(pattern*43+7);clk=1;#1;clk=0;#1;check;
            oe_n=1;check;
        end
        $display("PASS: tb_ttl_74x794");$finish;
    end
endmodule
