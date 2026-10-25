`timescale 1ns/1ps
module tb_ttl_74x366;
    logic [5:0] a, y;
    logic g1_n, g2_n;
    ttl_74x366 dut(.a(a), .g1_n(g1_n), .g2_n(g2_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=6'h2A; g1_n=0; g2_n=0; #1; if (y !== ~6'h2A) errors++;
        g1_n=1; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x366: %0d errors", errors);
        $display("PASS: tb_ttl_74x366");
        $finish;
    end
endmodule
