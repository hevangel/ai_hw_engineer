`timescale 1ns/1ps
module tb_ttl_74x475;
    logic [8:0] addr;
    logic cs_n,drive;
    logic [7:0] data_out,expected;
    ttl_74x475 #(.INIT_FILE("tb/data/rom_ttl_74x475.hex")) dut(.*);
    initial begin
        addr=0;cs_n=1;#1;
        if (drive!==0 || data_out!=='0) $fatal(1,"deselected");
        cs_n=0;
        for (int i=0;i<512;i++) begin
            addr=9'(i);expected=8'((i*37)^(i>>3)^'ha5);#1;
            if (!drive || data_out!==expected) $fatal(1,"ROM address %0d",i);
        end
        cs_n=1;#1;
        if (drive!==0 || data_out!=='0) $fatal(1,"deselection");
        $display("PASS: tb_ttl_74x475");$finish;
    end
endmodule
