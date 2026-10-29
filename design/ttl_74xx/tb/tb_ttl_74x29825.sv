`timescale 1ns/1ps
module tb_ttl_74x29825;
    logic clk, oe_n, clr_n, ce_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x29825 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; ce_n = 0; d = 8'hF0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        tick;
        if (q !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x29825: %0d errors", errors);
        $display("PASS: tb_ttl_74x29825");
        $finish;
    end
endmodule
