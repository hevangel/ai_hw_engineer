`timescale 1ns/1ps
module tb_ttl_74x405;
    logic [2:0] a;
    logic g1_n, g2_n, g3;
    logic [7:0] y_n;
    ttl_74x405 dut(.a(a), .g1_n(g1_n), .g2_n(g2_n), .g3(g3), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        a=3'd5; g1_n=0; g2_n=0; g3=1; #1;
        if (y_n !== 8'hDF) errors++;
        g3=0; #1; if (y_n !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x405: %0d errors", errors);
        $display("PASS: tb_ttl_74x405");
        $finish;
    end
endmodule
