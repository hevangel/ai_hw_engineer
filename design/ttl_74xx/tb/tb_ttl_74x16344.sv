`timescale 1ns/1ps
module tb_ttl_74x16344;
    logic [7:0] a;
    logic [3:0] oe_n;
    logic [31:0] b,drive;
    ttl_74x16344 dut(.*);
    initial begin
        for(int controls=0;controls<16;controls++) begin
            oe_n=4'(controls);
            for(int data_value=0;data_value<256;data_value++) begin
                a=8'(data_value);#1;
                for(int addr=0;addr<8;addr++) begin
                    for(int copy=0;copy<4;copy++) begin
                        if(drive[addr*4+copy]!==!oe_n[addr/2] ||
                           b[addr*4+copy]!==(!oe_n[addr/2] && a[addr])) $fatal(1,"address/copy/enable mapping");
                    end
                end
            end
        end
        $display("PASS: tb_ttl_74x16344");$finish;
    end
endmodule
