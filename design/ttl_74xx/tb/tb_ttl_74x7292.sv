`timescale 1ns/1ps
module tb_ttl_74x7292;
    logic clk, rst;
    logic [31:0] n;
    logic out;
    ttl_74x7292 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; n = 32'd3; rst = 1; #1; rst = 0; #1;
        if (out !== 1) errors++;
        tick;
        if (out !== 0) errors++;
        tick; tick;
        if (out !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7292: %0d errors", errors);
        $display("PASS: tb_ttl_74x7292");
        $finish;
    end
endmodule
