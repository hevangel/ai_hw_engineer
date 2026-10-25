`timescale 1ns/1ps
module tb_ttl_74x526;
    logic [15:0] p;
    logic match;
    ttl_74x526 #(.PATTERN(16'hDEAD)) dut(.*);
    int errors;
    initial begin
        errors=0;
        p=16'hDEAD; #1; if (!match) errors++;
        p=16'hBEEF; #1; if (match) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x526: %0d errors", errors);
        $display("PASS: tb_ttl_74x526");
        $finish;
    end
endmodule
