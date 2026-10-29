`timescale 1ns/1ps
module tb_ttl_74x7273;
    logic clk, clr_n;
    logic [7:0] d, q;
    ttl_74x7273 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; d = 8'h5A;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (q !== 8'h00) errors++;
        tick;
        if (q !== 8'h5A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7273: %0d errors", errors);
        $display("PASS: tb_ttl_74x7273");
        $finish;
    end
endmodule
