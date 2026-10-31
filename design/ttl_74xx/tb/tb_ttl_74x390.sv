`timescale 1ns/1ps
module tb_ttl_74x390;
    logic [1:0] clk_a,clk_b,clr;
    logic [3:0] q0,q1;
    int ea[2],eb[2];
    ttl_74x390 dut(.*);
    task automatic check;
        #1;
        if(q0!==4'(ea[0]+2*eb[0]) || q1!==4'(ea[1]+2*eb[1])) $fatal(1,"counter sections");
    endtask
    initial begin
        clk_a=0;clk_b=0;clr=0;ea[0]=0;ea[1]=0;eb[0]=0;eb[1]=0;
        #1;clr=3;check;clr=0;
        for(int i=0;i<40;i++) begin
            for(int bank=0;bank<2;bank++) begin
                clk_a[bank]=1;check;clk_a[bank]=0;ea[bank]^=1;check;
                if((i+bank)%3==0) begin
                    clk_b[bank]=1;check;clk_b[bank]=0;eb[bank]=(eb[bank]+1)%5;check;
                end
            end
        end
        clr[0]=1;ea[0]=0;eb[0]=0;check;clr[0]=0;
        clr[1]=1;ea[1]=0;eb[1]=0;check;
        $display("PASS: tb_ttl_74x390");$finish;
    end
endmodule
