`timescale 1ns/1ps
module tb_ttl_74x16821;
    logic clk, oe_n;
    logic [19:0] d, q;
    logic q_oe_n;
    ttl_74x16821 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 20'hC3A5A; #1; clk = 1; #1;
        if (q !== 20'hC3A5A) errors++;
        oe_n = 1; #1;
        if (q !== 0 || q_oe_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16821: %0d errors", errors);
        $display("PASS: tb_ttl_74x16821");
        $finish;
    end
endmodule
