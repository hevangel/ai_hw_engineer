`timescale 1ns/1ps
module tb_ttl_74x468;
    logic [7:0] a, y;
    logic g1_n, g2_n;
    ttl_74x468 dut(.a(a), .g1_n(g1_n), .g2_n(g2_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=8'h33; g1_n=0; g2_n=0; #1; if (y !== ~8'h33) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x468: %0d errors", errors);
        $display("PASS: tb_ttl_74x468");
        $finish;
    end
endmodule
