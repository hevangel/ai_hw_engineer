`timescale 1ns/1ps
module tb_ttl_74x4078;
    logic [7:0] a;
    logic y_or, y_nor;
    ttl_74x4078 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 8'h00; #1; if (y_or !== 0 || y_nor !== 1) errors++;
        a = 8'h01; #1; if (y_or !== 1 || y_nor !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4078: %0d errors", errors);
        $display("PASS: tb_ttl_74x4078");
        $finish;
    end
endmodule
