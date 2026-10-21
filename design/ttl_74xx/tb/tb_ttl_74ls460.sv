`timescale 1ns/1ps
module tb_ttl_74ls460;
    logic [9:0] a, b;
    logic a_eq_b, a_gt_b, a_lt_b;
    ttl_74ls460 dut(.a(a), .b(b), .a_eq_b(a_eq_b), .a_gt_b(a_gt_b), .a_lt_b(a_lt_b));
    int errors;
    initial begin
        errors = 0;
        a=10'd100; b=10'd100; #1; if (!a_eq_b) errors++;
        a=10'd200; b=10'd100; #1; if (!a_gt_b) errors++;
        a=10'd50;  b=10'd100; #1; if (!a_lt_b) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74ls460: %0d errors", errors);
        $display("PASS: tb_ttl_74ls460");
        $finish;
    end
endmodule
