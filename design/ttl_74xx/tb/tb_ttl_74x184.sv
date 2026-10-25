`timescale 1ns/1ps
module tb_ttl_74x184;
    logic [7:0] bcd;
    logic [6:0] bin;
    ttl_74x184 dut(.*);
    initial begin
        for (int n=0;n<100;n++) begin
            bcd={4'(n/10),4'(n%10)}; #1;
            if(bin !== 7'(n)) $fatal(1,"BCD conversion truncation at %d",n);
        end
        bcd=8'hff; #1; if(bin !== 0) $fatal(1,"invalid BCD");
        $display("PASS: tb_ttl_74x184 (all 100 two-digit inputs)");
        $finish;
    end
endmodule
