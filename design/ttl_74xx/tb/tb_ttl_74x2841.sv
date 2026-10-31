`timescale 1ns/1ps
module tb_ttl_74x2841;
    logic oe_n, le;
    logic [9:0] d, q;
    logic hiz;
    ttl_74x2841 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 10'h2C7; #1;
        if (q !== 10'h2C7) errors++;
        le = 0; d = 10'h000; #1;
        if (q !== 10'h2C7) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2841: %0d errors", errors);
        $display("PASS: tb_ttl_74x2841");
        $finish;
    end
endmodule
