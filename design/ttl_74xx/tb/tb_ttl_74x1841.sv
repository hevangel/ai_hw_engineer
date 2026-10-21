`timescale 1ns/1ps
module tb_ttl_74x1841;
    logic le, oe_n;
    logic [9:0] d, q;
    logic q_oe_n;
    ttl_74x1841 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 10'h2A5; #1;
        if (q !== 10'h2A5) errors++;
        le = 0; d = 10'h0; #1;
        if (q !== 10'h2A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1841: %0d errors", errors);
        $display("PASS: tb_ttl_74x1841");
        $finish;
    end
endmodule
