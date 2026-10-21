`timescale 1ns/1ps
module tb_ttl_74x25244;
    logic oe1_n, oe2_n;
    logic [3:0] a1, a2, y1, y2;
    logic hiz1, hiz2;
    ttl_74x25244 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a1 = 4'h7; a2 = 4'hE; #1;
        if (y1 !== 4'h7 || y2 !== 4'hE) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x25244: %0d errors", errors);
        $display("PASS: tb_ttl_74x25244");
        $finish;
    end
endmodule
