`timescale 1ns/1ps
module tb_ttl_74x4022;
    logic clk, clk_en_n, rst;
    logic [7:0] q;
    logic cout;
    ttl_74x4022 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; clk_en_n = 0; rst = 1; #1; rst = 0; #1;
        if (q !== 8'b00000001) errors++;
        tick;
        if (q !== 8'b00000010) errors++;
        for (int i = 0; i < 7; i++) tick;
        if (q !== 8'b00000001) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4022: %0d errors", errors);
        $display("PASS: tb_ttl_74x4022");
        $finish;
    end
endmodule
