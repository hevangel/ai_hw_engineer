`timescale 1ns/1ps
module tb_ttl_74x311;
    logic clk,we_n,cs_n;
    logic [3:0] addr;
    logic [8:0] data_in,data_out,expected;
    logic [8:0] reference [0:15];
    logic latch_en;

    ttl_74x311 dut(.*);
    task automatic pulse;#1;clk=1;#1;clk=0;#1;endtask
    initial begin
        clk=0;we_n=1;cs_n=1;addr=0;data_in=0;latch_en=1;
        for(int pass=0;pass<3;pass++) begin
            cs_n=0;we_n=0;
            for(int i=0;i<16;i++) begin
                addr=4'(i);data_in=9'((i*37)^(pass*91)^'h5a);reference[i]=data_in;pulse;
            end
            we_n=1;
            for(int i=0;i<16;i++) begin
                addr=4'(i);data_in=~reference[i];pulse;
                expected=reference[i];
                if(data_out!==expected) $fatal(1,"RAM pass/address %0d %0d",pass,i);
            end
            cs_n=1;we_n=0;
            for(int i=0;i<16;i++) begin addr=4'(i);data_in='1;pulse;end
            cs_n=0;we_n=1;
            for(int i=0;i<16;i++) begin
                addr=4'(i);#1;expected=reference[i];
                if(data_out!==expected) $fatal(1,"inactive CS write protection");
            end
        end

        addr=0;latch_en=1;#1;latch_en=0;#1;
        expected=reference[0];addr=1;#1;
        if(data_out!==expected) $fatal(1,"output latch hold");
        latch_en=1;#1;if(data_out!==reference[1]) $fatal(1,"output latch transparent");

        cs_n=1;#1;if(data_out!=='0) $fatal(1,"deselected data mask");
        $display("PASS: tb_ttl_74x311");$finish;
    end
endmodule
