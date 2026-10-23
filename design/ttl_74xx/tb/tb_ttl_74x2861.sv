`timescale 1ns/1ps
module tb_ttl_74x2861;
    logic oe_n, dir;
    logic [9:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    ttl_74x2861 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 10'h3C3; b_in = 0; #1;
        if (b_out !== 10'h3C3) errors++;
        dir = 0; b_in = 10'h055; #1;
        if (a_out !== 10'h055) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2861: %0d errors", errors);
        $display("PASS: tb_ttl_74x2861");
        $finish;
    end
endmodule
