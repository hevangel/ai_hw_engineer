`timescale 1ns/1ps
module tb_ttl_74x161284;
    logic oe_n, dir;
    logic [18:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    ttl_74x161284 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 19'h2AAAA; b_in = 0; #1;
        if (b_out !== 19'h2AAAA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x161284: %0d errors", errors);
        $display("PASS: tb_ttl_74x161284");
        $finish;
    end
endmodule
