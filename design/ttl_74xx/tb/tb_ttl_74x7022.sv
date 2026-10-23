`timescale 1ns/1ps
module tb_ttl_74x7022;
    logic clk, clk_en_n, rst;
    logic [7:0] q;
    logic cout;
    ttl_74x7022 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; clk_en_n = 0; rst = 0; #1; rst=1; #1; rst=0; #1;
        // Explicit reset represents the power-up clear in this pure-digital contract.
        if (q !== 8'b00000001) errors++;
        tick;
        if (q !== 8'b00000010) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7022: %0d errors", errors);
        $display("PASS: tb_ttl_74x7022");
        $finish;
    end
endmodule
