`timescale 1ns/1ps
module tb_ttl_74x844;
    logic le, pre_n, clr_n, oe_n;
    logic [8:0] d, q;
    logic q_oe_n;
    ttl_74x844 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; pre_n = 1; clr_n = 1; le = 1; d = 9'h055; #1;
        if (q !== ~9'h055) errors++;
        le = 0; d = 0; #1; if (q !== ~9'h055) errors++;
        pre_n = 0; #1; if (q !== 9'h1FF) errors++; pre_n = 1;
        clr_n = 0; #1; if (q !== 0) errors++; clr_n = 1;
        if (errors != 0) $fatal(1, "tb_ttl_74x844: %0d errors", errors);
        $display("PASS: tb_ttl_74x844");
        $finish;
    end
endmodule
