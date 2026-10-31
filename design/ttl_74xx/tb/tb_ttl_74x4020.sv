`timescale 1ns/1ps
module tb_ttl_74x4020;
    logic clk, rst;
    logic [13:0] q;
    ttl_74x4020 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; rst = 1; #1; rst = 0; #1;
        if (q !== 14'd0) errors++;
        tick;
        if (q !== 14'd1) errors++;
        for (int i = 0; i < 5; i++) tick;
        if (q !== 14'd6) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4020: %0d errors", errors);
        $display("PASS: tb_ttl_74x4020");
        $finish;
    end
endmodule
