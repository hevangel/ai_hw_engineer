`timescale 1ns/1ps
module tb_ttl_74x299;
    logic clk,clr_n,oe_n,s0,s1,din_right,din_left,q0,q7;
    logic [7:0] p,q,drive_en,expected;
    ttl_74x299 dut(.*);
    task automatic tick;clk=0;#1;clk=1;#1;clk=0;#1;endtask
    initial begin
        clk=0;clr_n=0;oe_n=0;s0=0;s1=0;din_right=0;din_left=0;p=0;#1;
        if(q!==0)$fatal(1,"clear");clr_n=1;
        for(int v=0;v<256;v++) begin
            p=8'(v);s0=1;s1=1;tick;expected=p;
            if(q!==expected || drive_en!==0)$fatal(1,"parallel load release");
            oe_n=1;s0=0;s1=0;#1;
            if(q!==0 || drive_en!==0 || q0!==expected[0] || q7!==expected[7])
                $fatal(1,"serial endpoints while parallel disabled");
            oe_n=0;
            for(int i=0;i<8;i++) begin
                s0=1;s1=0;din_right=1'(i%2);tick;expected={din_right,expected[7:1]};
                if(q!==expected || drive_en!==255)$fatal(1,"shift right");
            end
            for(int i=0;i<8;i++) begin
                s0=0;s1=1;din_left=1'(i%2);tick;expected={expected[6:0],din_left};
                if(q!==expected)$fatal(1,"shift left");
            end
            s0=0;s1=0;tick;if(q!==expected)$fatal(1,"hold");
        end
        $display("PASS: tb_ttl_74x299 (256 loads, shift directions, hold and drive masks)");
        $finish;
    end
endmodule
