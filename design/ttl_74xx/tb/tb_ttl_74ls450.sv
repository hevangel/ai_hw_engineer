`timescale 1ns/1ps
module tb_ttl_74ls450;
    logic [3:0] s;
    logic [15:0] d;
    logic g_n, y, y_n;
    ttl_74ls450 dut(.s(s), .d(d), .g_n(g_n), .y(y), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        d=16'h5A5A; g_n=0;
        s=4'd0; #1; if (y !== d[0] || y_n !== ~d[0]) errors++;
        g_n=1; #1; if (y !== 0 || y_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74ls450: %0d errors", errors);
        $display("PASS: tb_ttl_74ls450");
        $finish;
    end
endmodule
