`timescale 1ns/1ps
module tb_ttl_74x7817;
    logic clk,clr_n,we,re,full,empty;
    logic [35:0] din,dout;
    logic [35:0] reference [0:4160];
    int head,tail,count;
    logic [31:0] rng;
    ttl_74x7817 dut(.*);
    task automatic step(input logic w,r,input logic [35:0] data);
        logic take_read,take_write;
        if (full !== (count==64) || empty !== (count==0)) $fatal(1,"flags count=%0d",count);
        if (count>0 && dout!==reference[head]) $fatal(1,"ordering head=%0d",head);
        take_read=r && count>0;take_write=w && count<64;
        we=w;re=r;din=data;#1;clk=1;#1;clk=0;#1;
        if (take_read) begin head++;count--;end
        if (take_write) begin reference[tail]=data;tail++;count++;end
        if (full !== (count==64) || empty !== (count==0)) $fatal(1,"post flags");
    endtask
    initial begin
        clk=0;clr_n=1;we=0;re=0;din=0;head=0;tail=0;count=0;rng=32'hcafe1234;
        #1;clr_n=0;#1;clr_n=1;#1;
        step(0,1,'0);
        for(int i=0;i<64;i++) step(1,0,36'(i*37+11));
        step(1,0,'1);step(1,1,'1);
        while(count>0) step(0,1,'0);
        head=0;tail=0;
        for(int i=0;i<4000;i++) begin
            rng=(rng<<1)^((rng[31])?32'h04c11db7:0);
            step(rng[0],rng[9],36'(rng));
        end
        while(count>0) step(0,1,'0);
        // Reset with outstanding data must discard it and reset both pointers.
        step(1,0,'1);clr_n=0;#1;head=0;tail=0;count=0;clr_n=1;#1;
        step(1,0,36'('h5a));step(0,1,'0);
        $display("PASS: tb_ttl_74x7817");$finish;
    end
endmodule
