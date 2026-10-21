`timescale 1ns/1ps
module tb_ttl_74x3573;
    logic le, oe_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x3573 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 8'hC3; #1;
        if (q !== 8'hC3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x3573: %0d errors", errors);
        $display("PASS: tb_ttl_74x3573");
        $finish;
    end
endmodule
