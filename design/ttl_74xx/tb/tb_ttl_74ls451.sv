`timescale 1ns/1ps
module tb_ttl_74ls451;
    logic [2:0] s;
    logic [1:0] g_n, y;
    logic [7:0] d0, d1;
    ttl_74ls451 dut(.s(s), .g_n(g_n), .d0(d0), .d1(d1), .y(y));
    int errors;
    initial begin
        errors = 0;
        d0=8'h5A; d1=8'hA5; g_n=0;
        s=3'd1; #1; if (y[0] !== d0[1] || y[1] !== d1[1]) errors++;
        g_n=2'b11; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74ls451: %0d errors", errors);
        $display("PASS: tb_ttl_74ls451");
        $finish;
    end
endmodule
