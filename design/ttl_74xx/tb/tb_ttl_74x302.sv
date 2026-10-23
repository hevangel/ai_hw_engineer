`timescale 1ns/1ps
module tb_ttl_74x302;
    logic clk,we_n,cs_n;
    logic [7:0] addr;
    logic [0:0] data_in,data_out,expected;
    logic [0:0] reference [0:255];

    ttl_74x302 dut(.*);
    task automatic pulse;#1;clk=1;#1;clk=0;#1;endtask
    initial begin
        clk=0;we_n=1;cs_n=1;addr=0;data_in=0;
        for(int pass=0;pass<3;pass++) begin
            cs_n=0;we_n=0;
            for(int i=0;i<256;i++) begin
                addr=8'(i);data_in=1'((i*37)^(pass*91)^'h5a);reference[i]=data_in;pulse;
            end
            we_n=1;
            for(int i=0;i<256;i++) begin
                addr=8'(i);data_in=~reference[i];pulse;
                expected=reference[i];
                if(data_out!==expected) $fatal(1,"RAM pass/address %0d %0d",pass,i);
            end
            cs_n=1;we_n=0;
            for(int i=0;i<256;i++) begin addr=8'(i);data_in='1;pulse;end
            cs_n=0;we_n=1;
            for(int i=0;i<256;i++) begin
                addr=8'(i);#1;expected=reference[i];
                if(data_out!==expected) $fatal(1,"inactive CS write protection");
            end
        end

        cs_n=1;#1;if(data_out!=='0) $fatal(1,"deselected data mask");
        $display("PASS: tb_ttl_74x302");$finish;
    end
endmodule
