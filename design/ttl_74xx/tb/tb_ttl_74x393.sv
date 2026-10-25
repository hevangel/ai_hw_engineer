`timescale 1ns/1ps
module tb_ttl_74x393;
    logic [1:0] clk,clr;
    logic [3:0] q0,q1;
    int expected[2];
    ttl_74x393 dut(.*);
    task automatic check;
        #1;if(q0!==4'(expected[0]) || q1!==4'(expected[1])) $fatal(1,"counter edge or independence");
    endtask
    initial begin
        clk=0;clr=0;expected[0]=0;expected[1]=0;
        #1;clr=3;check;clr=0;
        for(int i=0;i<40;i++) begin
            clk[0]=1;check;clk[0]=0;expected[0]=(expected[0]+1)%16;check;
            if(i%3==0) begin clk[1]=1;check;clk[1]=0;expected[1]=(expected[1]+1)%16;check;end
        end
        clr[0]=1;expected[0]=0;check;clr[0]=0;
        clr[1]=1;expected[1]=0;check;
        $display("PASS: tb_ttl_74x393");$finish;
    end
endmodule
