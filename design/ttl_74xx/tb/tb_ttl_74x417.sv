`timescale 1ns/1ps
module tb_ttl_74x417;
    logic clk_a, clk_b, clr_n, load_n;
    logic [3:0] d;
    logic q_a;
    logic [2:0] q_b;
    ttl_74x417 dut(.clk_a(clk_a), .clk_b(clk_b), .clr_n(clr_n), .load_n(load_n), .d(d), .q_a(q_a), .q_b(q_b));
    int errors;
    initial begin
        errors = 0;
        clk_a=0; clk_b=0; clr_n=0; load_n=1; d=0; #1;
        if (q_a !== 0 || q_b !== 0) errors++;
        clr_n=1; load_n=0; d=4'b1011; #1;
        if (q_a !== 1 || q_b !== 3'b101) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x417: %0d errors", errors);
        $display("PASS: tb_ttl_74x417");
        $finish;
    end
endmodule
