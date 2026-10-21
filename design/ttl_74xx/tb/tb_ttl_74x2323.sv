`timescale 1ns/1ps
module tb_ttl_74x2323;
    logic [1:0] line,out;logic strobe;
    ttl_74x2323 dut(.*);
    initial begin
        for(int v=0;v<8;v++) begin
            {strobe,line}=3'(v);#1;
            for(int i=0;i<2;i++) if(out[i]!==(!line[i] && !strobe)) $fatal(1,"receiver table");
        end
        $display("PASS: tb_ttl_74x2323");$finish;
    end
endmodule
