`timescale 1ns/1ps
module tb_ttl_74x16826;
    logic [17:0] a, y;
    logic oe1_n, oe2_n;
    ttl_74x16826 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a = 18'h0_5555; #1;
        if (y !== 18'h3_AAAA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16826: %0d errors", errors);
        $display("PASS: tb_ttl_74x16826");
        $finish;
    end
endmodule
