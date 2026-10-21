`timescale 1ns/1ps
module tb_ttl_74x351;
    logic [2:0] s;
    logic [3:0] d_common, d0_extra, d1_extra;
    logic [1:0] g_n, y;
    ttl_74x351 dut(.s(s), .d_common(d_common), .d0_extra(d0_extra), .d1_extra(d1_extra), .g_n(g_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        g_n=2'b00; d_common=4'b1010; d0_extra=4'b1100; d1_extra=4'b0011;
        s=3'd0; #1; if (y[0] !== 0 || y[1] !== 0) errors++;
        s=3'd1; #1; if (y[0] !== 1 || y[1] !== 1) errors++;
        s=3'd4; #1; if (y[0] !== 0 || y[1] !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x351: %0d errors", errors);
        $display("PASS: tb_ttl_74x351");
        $finish;
    end
endmodule
