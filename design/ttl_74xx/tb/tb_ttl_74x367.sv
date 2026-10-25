`timescale 1ns/1ps
module tb_ttl_74x367;
    logic [5:0] a, y;
    logic g1_n, g2_n;
    ttl_74x367 dut(.a(a), .g1_n(g1_n), .g2_n(g2_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=6'h3F; g1_n=0; g2_n=0; #1; if (y !== 6'h3F) errors++;
        g1_n=1; #1; if (y[3:0] !== 0 || y[5:4] !== 2'b11) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x367: %0d errors", errors);
        $display("PASS: tb_ttl_74x367");
        $finish;
    end
endmodule
