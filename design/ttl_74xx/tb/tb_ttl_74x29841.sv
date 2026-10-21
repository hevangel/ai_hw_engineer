`timescale 1ns/1ps
module tb_ttl_74x29841;
    logic oe_n, le;
    logic [9:0] d, q;
    logic hiz;
    ttl_74x29841 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 10'h1A3; #1;
        if (q !== 10'h1A3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x29841: %0d errors", errors);
        $display("PASS: tb_ttl_74x29841");
        $finish;
    end
endmodule
