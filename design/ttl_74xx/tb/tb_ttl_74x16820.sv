`timescale 1ns/1ps
module tb_ttl_74x16820;
    logic clk, oe_n;
    logic [9:0] d, q, q_n;
    ttl_74x16820 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 10'h2A5; #1; clk = 1; #1;
        if (q !== 10'h2A5) errors++;
        if (q_n !== ~10'h2A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16820: %0d errors", errors);
        $display("PASS: tb_ttl_74x16820");
        $finish;
    end
endmodule
