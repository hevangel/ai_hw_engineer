`timescale 1ns/1ps
module tb_ttl_74x878;
    logic clk1, sclr1_n, oe1_n;
    logic [3:0] d1, q1;
    logic q1_oe_n;
    logic clk2, sclr2_n, oe2_n;
    logic [3:0] d2, q2;
    logic q2_oe_n;
    ttl_74x878 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk1 = 0; clk2 = 0; sclr1_n = 1; sclr2_n = 1;
        oe1_n = 0; oe2_n = 0; d2 = 0;
        d1 = 4'hA; clk1 = 1; #1; clk1 = 0; #1;
        if (q1 !== 4'hA) errors++;
        // Sync clear: pulse with sclr_n low.
        sclr1_n = 0; clk1 = 1; #1; clk1 = 0; #1;
        if (q1 !== 0) errors++;
        sclr1_n = 1;
        // Sync clear does NOT take effect asynchronously.
        d1 = 4'h5; sclr1_n = 0; #1;
        if (q1 !== 0) errors++;  // still 0 from previous clock, no new edge
        clk1 = 1; #1;
        if (q1 !== 0) errors++;  // sclr triggered on this edge
        if (errors != 0) $fatal(1, "tb_ttl_74x878: %0d errors", errors);
        $display("PASS: tb_ttl_74x878");
        $finish;
    end
endmodule
