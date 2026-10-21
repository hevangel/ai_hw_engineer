`timescale 1ns/1ps
module tb_ttl_74x354;
    logic le, oe_n;
    logic [2:0] s;
    logic [7:0] d;
    logic y;
    ttl_74x354 dut(.le(le), .oe_n(oe_n), .s(s), .d(d), .y(y));
    int errors;
    initial begin
        errors = 0;
        le=1; oe_n=0; d=8'b10101010; s=3'd1; #1;
        if (y !== d[1]) errors++;
        le=0; d=8'h00; #1;
        if (y !== 1'b1) errors++; // still d[1] of 8'hAA = 1
        oe_n=1; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x354: %0d errors", errors);
        $display("PASS: tb_ttl_74x354");
        $finish;
    end
endmodule
