`timescale 1ns/1ps
module tb_ttl_74x843;
    logic le, pre_n, clr_n, oe_n;
    logic [8:0] d, q;
    logic q_oe_n;
    ttl_74x843 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; pre_n = 1; clr_n = 1; le = 1; d = 9'h055; #1;
        if (q !== 9'h055) errors++;
        d = 9'h0AA; #1; if (q !== 9'h0AA) errors++;
        le = 0; d = 9'h0; #1; if (q !== 9'h0AA) errors++;
        clr_n = 0; #1; if (q !== 9'h000) errors++; clr_n = 1;
        pre_n = 0; #1; if (q !== 9'h1FF) errors++;
        // Pre priority over clr.
        clr_n = 0; #1; if (q !== 9'h1FF) errors++;
        pre_n = 1; clr_n = 1;
        oe_n = 1; #1; if (q !== 0 || q_oe_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x843: %0d errors", errors);
        $display("PASS: tb_ttl_74x843");
        $finish;
    end
endmodule
