`timescale 1ns/1ps
module tb_ttl_74x7540;
    logic oe1_n, oe2_n;
    logic [7:0] a, y;
    logic hiz;
    ttl_74x7540 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a = 8'h0F; #1;
        if (y !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7540: %0d errors", errors);
        $display("PASS: tb_ttl_74x7540");
        $finish;
    end
endmodule
