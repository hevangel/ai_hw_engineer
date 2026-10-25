`timescale 1ns/1ps
module tb_ttl_74x162241;
    logic [15:0] a, y;
    logic oe1_n, oe2;
    ttl_74x162241 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2 = 1; a = 16'hAA55; #1;
        if (y !== 16'hAA55) errors++;
        oe1_n = 1; oe2 = 0; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162241: %0d errors", errors);
        $display("PASS: tb_ttl_74x162241");
        $finish;
    end
endmodule
