`timescale 1ns/1ps
module tb_ttl_74x353;
    logic [1:0] s, g_n, y_n;
    logic [3:0] d0, d1;
    ttl_74x353 dut(.s(s), .g_n(g_n), .d0(d0), .d1(d1), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        d0=4'b1010; d1=4'b0101; g_n=0;
        s=2'd0; #1; if (y_n[0] !== ~d0[0] || y_n[1] !== ~d1[0]) errors++;
        g_n=2'b11; #1; if (y_n !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x353: %0d errors", errors);
        $display("PASS: tb_ttl_74x353");
        $finish;
    end
endmodule
