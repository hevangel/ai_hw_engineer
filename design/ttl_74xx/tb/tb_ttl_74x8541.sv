`timescale 1ns/1ps
module tb_ttl_74x8541;
    logic oe_n, inv;
    logic [7:0] a, y;
    logic hiz;
    ttl_74x8541 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; inv = 0; a = 8'h5A; #1;
        if (y !== 8'h5A) errors++;
        inv = 1; #1;
        if (y !== 8'hA5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8541: %0d errors", errors);
        $display("PASS: tb_ttl_74x8541");
        $finish;
    end
endmodule
