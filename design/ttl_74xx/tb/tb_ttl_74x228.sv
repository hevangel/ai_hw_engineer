`timescale 1ns/1ps
module tb_ttl_74x228;
    logic clk,clr_n,we,re,full,empty;
    logic [3:0] din,dout;
    logic [3:0] golden[0:15];
    integer head,tail,count;
    logic [31:0] random_state;
    ttl_74x228 dut(.*);
    task automatic transact(input bit push,pop,input logic [3:0] value);
        bit accepted_push,accepted_pop;
        if(full !== (count==16) || empty !== (count==0)) $fatal(1,"FIFO flags");
        if(count>0 && dout !== golden[head]) $fatal(1,"FIFO ordering");
        accepted_push=push && count<16;accepted_pop=pop && count>0;
        we=push;re=pop;din=value;clk=0;#1;clk=1;#1;clk=0;#1;
        if(accepted_push) begin golden[tail]=value;tail=(tail+1)%16;end
        if(accepted_pop) head=(head+1)%16;
        count=count+int'(accepted_push)-int'(accepted_pop);
        if(full !== (count==16) || empty !== (count==0)) $fatal(1,"FIFO post flags");
        if(count>0 && dout !== golden[head]) $fatal(1,"FIFO post ordering");
    endtask
    initial begin
        clk=0;clr_n=0;we=0;re=0;din=0;head=0;tail=0;count=0;random_state=32'h78294abc;#1;
        clr_n=1;#1;
        transact(0,1,'0);
        for(int i=0;i<19;i++) transact(1,0,4'(i));
        for(int i=0;i<19;i++) transact(0,1,'0);
        for(int i=0;i<2000;i++) begin
            random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            transact(random_state[0],random_state[5],4'(random_state>>8));
        end
        while(count>0) transact(0,1,'0);
        $display("PASS: tb_ttl_74x228 (full, empty, wraparound, 2000 mixed transactions)");
        $finish;
    end
endmodule
