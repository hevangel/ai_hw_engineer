`timescale 1ns/1ps
module tb_ttl_74x4050;
    logic [5:0] a, y;
    ttl_74x4050 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 6'b110011; #1;
        if (y !== 6'b110011) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4050: %0d errors", errors);
        $display("PASS: tb_ttl_74x4050");
        $finish;
    end
endmodule
