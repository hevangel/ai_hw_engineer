`timescale 1ns/1ps
module tb_ttl_74x16843;
    logic le, pre_n, clr_n, oe_n;
    logic [17:0] d, q;
    logic q_oe_n;
    ttl_74x16843 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; pre_n = 1; clr_n = 1; le = 1; d = 18'h2_ABCD; #1;
        if (q !== 18'h2_ABCD) errors++;
        pre_n = 0; #1; if (q !== 18'h3_FFFF) errors++; pre_n = 1;
        clr_n = 0; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16843: %0d errors", errors);
        $display("PASS: tb_ttl_74x16843");
        $finish;
    end
endmodule
