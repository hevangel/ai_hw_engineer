`timescale 1ns/1ps
module tb_ttl_74x162541;
    logic [15:0] a, y;
    logic oe1_n, oe2_n;
    ttl_74x162541 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a = 16'hCAFE; #1;
        if (y !== 16'hCAFE) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162541: %0d errors", errors);
        $display("PASS: tb_ttl_74x162541");
        $finish;
    end
endmodule
