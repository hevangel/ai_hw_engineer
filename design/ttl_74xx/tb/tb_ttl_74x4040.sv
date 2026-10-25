`timescale 1ns/1ps
module tb_ttl_74x4040;
    logic clk, rst;
    logic [11:0] q;
    ttl_74x4040 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; rst = 1; #1; rst = 0; #1;
        for (int i = 0; i < 5; i++) tick;
        if (q !== 12'd5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4040: %0d errors", errors);
        $display("PASS: tb_ttl_74x4040");
        $finish;
    end
endmodule
