`timescale 1ns/1ps
module tb_ttl_74ls453;
    logic [1:0] s;
    logic [3:0] g_n, d0, d1, d2, d3, y;
    ttl_74ls453 dut(.s(s), .g_n(g_n), .d0(d0), .d1(d1), .d2(d2), .d3(d3), .y(y));
    int errors;
    initial begin
        errors = 0;
        d0=4'b1010; d1=4'b0101; d2=4'b1100; d3=4'b0011;
        g_n=0; s=2'd1; #1;
        if (y[0] !== d0[1]) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74ls453: %0d errors", errors);
        $display("PASS: tb_ttl_74ls453");
        $finish;
    end
endmodule
