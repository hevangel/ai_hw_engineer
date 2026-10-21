`timescale 1ns/1ps
module tb_ttl_74x1639;
    logic gab, gba_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x1639 dut(.*);
    int errors;
    initial begin
        errors = 0;
        gab = 1; gba_n = 1; a_in = 8'h42; #1;
        if (b_out !== 8'h42) errors++;
        gab = 0; gba_n = 0; b_in = 8'h33; #1;
        if (a_out !== 8'h33) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1639: %0d errors", errors);
        $display("PASS: tb_ttl_74x1639");
        $finish;
    end
endmodule
