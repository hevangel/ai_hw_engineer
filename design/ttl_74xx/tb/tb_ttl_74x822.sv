`timescale 1ns/1ps
module tb_ttl_74x822;
    logic clk, oe_n;
    logic [9:0] d, q;
    logic q_oe_n;
    ttl_74x822 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; d = 0;
        d = 10'h2A5; clk = 0; #1; clk = 1; #1;
        if (q !== ~10'h2A5) errors++;
        for (int v = 0; v < 1024; v += 37) begin
            d = v[9:0]; clk = 0; #1; clk = 1; #1;
            if (q !== ~v[9:0]) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x822: %0d errors", errors);
        $display("PASS: tb_ttl_74x822");
        $finish;
    end
endmodule
