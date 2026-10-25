`timescale 1ns/1ps
module tb_ttl_74x873;
    logic le1, clr1_n, oe1_n;
    logic [3:0] d1, q1;
    logic q1_oe_n;
    logic le2, clr2_n, oe2_n;
    logic [3:0] d2, q2;
    logic q2_oe_n;
    ttl_74x873 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; clr1_n = 1; clr2_n = 1; le1 = 1; le2 = 1;
        d1 = 4'hA; d2 = 4'h5; #1;
        if (q1 !== 4'hA || q2 !== 4'h5) errors++;

        le1 = 0; d1 = 4'h0; #1;
        if (q1 !== 4'hA) errors++;  // held

        clr1_n = 0; #1;
        if (q1 !== 0) errors++;
        if (q2 !== 4'h5) errors++;   // independent
        clr1_n = 1;

        oe2_n = 1; #1;
        if (q2 !== 0 || q2_oe_n !== 1) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x873: %0d errors", errors);
        $display("PASS: tb_ttl_74x873");
        $finish;
    end
endmodule
