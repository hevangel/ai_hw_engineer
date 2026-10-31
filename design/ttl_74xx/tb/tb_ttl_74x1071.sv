`timescale 1ns/1ps
module tb_ttl_74x1071;
    logic [9:0] external_data,external_drive,resolved,weak_drive,expected;
    ttl_74x1071 dut(.*);
    initial begin
        external_drive='1;external_data='0;expected=0;#1;
        for(int i=0;i<512;i++) begin
            external_drive=10'(i*713+7);external_data=10'(i*193+31);#1;
            for(int bit_index=0;bit_index<10;bit_index++) if(external_drive[bit_index]) expected[bit_index]=external_data[bit_index];
            if(resolved!==expected || weak_drive!==~external_drive) $fatal(1,"per-bit keeper update");
            external_drive='0;#1;external_data=~external_data;#1;
            if(resolved!==expected || weak_drive!=='1) $fatal(1,"weak hold retention");
        end
        $display("PASS: tb_ttl_74x1071");$finish;
    end
endmodule
