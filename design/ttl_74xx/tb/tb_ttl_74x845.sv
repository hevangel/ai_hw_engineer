`timescale 1ns/1ps
module tb_ttl_74x845;
    logic le, pre_n, clr_n, oe_n;
    logic [7:0] d, q;
    logic q_oe_n;
    ttl_74x845 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; pre_n = 1; clr_n = 1; le = 1; d = 8'h55; #1;
        if (q !== 8'h55) errors++;
        le = 0; d = 0; #1; if (q !== 8'h55) errors++;
        pre_n = 0; #1; if (q !== 8'hFF) errors++; pre_n = 1;
        clr_n = 0; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x845: %0d errors", errors);
        $display("PASS: tb_ttl_74x845");
        $finish;
    end
endmodule
