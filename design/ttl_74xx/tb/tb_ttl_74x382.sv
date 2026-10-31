`timescale 1ns/1ps
module tb_ttl_74x382;
    logic [3:0] a, b, f;
    logic [2:0] s;
    logic cn, cout, ovr;
    ttl_74x382 dut(.a(a), .b(b), .s(s), .cn(cn), .f(f), .cout(cout), .ovr(ovr));
    int errors;
    initial begin
        errors = 0;
        // Add: 4 + 4 = 8 (no overflow)
        a=4'h4; b=4'h4; cn=0; s=3'b011; #1;
        if (f !== 4'h8 || cout !== 0) errors++;
        // Overflow: 7 + 1 = 8 (signed overflow, +7+1 should be 8 but result is negative)
        a=4'h7; b=4'h1; cn=0; #1;
        if (f !== 4'h8 || ovr !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x382: %0d errors", errors);
        $display("PASS: tb_ttl_74x382");
        $finish;
    end
endmodule
