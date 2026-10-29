`timescale 1ns/1ps
module tb_ttl_74x162500;
    logic [17:0] a_in,b_in,a_out,b_out,expected_ab,expected_ba;
    logic clk_ab,clk_ba,le_ab,le_ba,oe_ab,oe_ba_n,ab_drive,ba_drive;

    ttl_74x162500 dut(.*);
    task automatic check;
        #1;
        if(ab_drive!==oe_ab || ba_drive!==!oe_ba_n ||
           b_out!==(oe_ab?expected_ab:18'd0) || a_out!==(!oe_ba_n?expected_ba:18'd0))
            $fatal(1,"independent direction/storage/drive");
    endtask
    task automatic pulse_ab;clk_ab=1;#1;clk_ab=0;#1;clk_ab=1;#1;endtask
    task automatic pulse_ba;clk_ba=1;#1;clk_ba=0;#1;clk_ba=1;#1;endtask
    initial begin
        clk_ab=1;clk_ba=1;le_ab=1;le_ba=1;oe_ab=1;oe_ba_n=0;
        a_in=0;b_in=0;expected_ab=0;expected_ba=0;check;
        for(int i=0;i<256;i++) begin
            le_ab=1;le_ba=1;#1;a_in=18'(i*977+17);b_in=18'(i*503+61);expected_ab=a_in;expected_ba=b_in;check;
            clk_ab=~clk_ab;clk_ba=~clk_ba;check;
            a_in=~a_in;b_in=~b_in;expected_ab=a_in;expected_ba=b_in;check;
            clk_ab=0;clk_ba=0;#1;le_ab=0;le_ba=0;#1;
            a_in=~a_in;b_in=~b_in;check;
            clk_ab=1;clk_ba=1;check; // noncapture edges
            clk_ab=0;expected_ab=a_in;check; // BA must remain unchanged
            clk_ba=0;expected_ba=b_in;check;
            a_in=~a_in;b_in=~b_in;check;
            oe_ab=0;oe_ba_n=1;check;
            clk_ab=1;clk_ba=1;#1;
            clk_ab=0;clk_ba=0;expected_ab=a_in;expected_ba=b_in;check;
            oe_ab=1;oe_ba_n=0;check;

        end
        $display("PASS: tb_ttl_74x162500");$finish;
    end
endmodule
