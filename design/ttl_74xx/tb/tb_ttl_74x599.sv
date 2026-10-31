`timescale 1ns/1ps
module tb_ttl_74x599;
    logic clk_shift,srclr_n,clk_lat,oe_n,sin;
    logic [7:0] q,history,stored;
    ttl_74x599 dut(.*);
    task automatic check;
        #1;
        if(q !== (oe_n?8'hff:stored))
            $fatal(1,"shift/storage/drive mismatch q=%h stored=%h history=%h",q,stored,history);
    endtask
    task automatic shift(input logic data);
        sin=data;#1;clk_shift=1;#1;clk_shift=0;
        for(int j=7;j>0;j--) history[j]=history[j-1];
        history[0]=data;check;
    endtask
    task automatic store;
        clk_lat=1;stored=history;#1;clk_lat=0;check;
    endtask
    initial begin
        clk_shift=0;clk_lat=0;srclr_n=1;oe_n=1;sin=0;history=0;stored=0;
        #1;srclr_n=0;#1;srclr_n=1;store;
        for(int word_value=0;word_value<256;word_value++) begin
            oe_n=word_value[0];check;
            for(int bit_index=0;bit_index<8;bit_index++) shift(word_value[7-bit_index]);
            store;oe_n=0;check;
            // Clear affects the shift register immediately, but not output storage.
            srclr_n=0;history=0;check;srclr_n=1;check;
        end
        // Simultaneous clocks latch the old shifter, then serial data shifts in.
        shift(1);shift(0);shift(1);
        sin=1;#1;clk_lat=1;clk_shift=1;stored=history;
        for(int j=7;j>0;j--) history[j]=history[j-1];
        history[0]=1;#1;clk_shift=0;clk_lat=0;check;
        $display("PASS: tb_ttl_74x599");$finish;
    end
endmodule
