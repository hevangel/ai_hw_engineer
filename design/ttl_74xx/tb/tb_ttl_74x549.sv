`timescale 1ns/1ps
module tb_ttl_74x549;
    logic le1, le2, clr_n;
    logic [7:0] d, q;
    ttl_74x549 dut(.*);
    int errors;
    initial begin
        errors=0; clr_n=1; #1; clr_n=0; #1; clr_n=1;
        le1=1; le2=1; d=8'h7E; #1;
        if (q !== 8'h7E) errors++;
        le1=0; le2=0; d=8'hFF; #1;
        if (q !== 8'h7E) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x549: %0d errors", errors);
        $display("PASS: tb_ttl_74x549");
        $finish;
    end
endmodule
