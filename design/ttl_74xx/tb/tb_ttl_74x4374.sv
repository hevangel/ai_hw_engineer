`timescale 1ns/1ps
module tb_ttl_74x4374;
    logic clk, oe_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x4374 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 8'h55;
        tick; tick;
        if (q !== 8'h55) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4374: %0d errors", errors);
        $display("PASS: tb_ttl_74x4374");
        $finish;
    end
endmodule
