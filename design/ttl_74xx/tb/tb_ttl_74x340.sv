`timescale 1ns/1ps
module tb_ttl_74x340;
    logic [7:0] a, y;
    logic oe1_n, oe2_n;
    ttl_74x340 dut(.a(a), .oe1_n(oe1_n), .oe2_n(oe2_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=8'h5A; oe1_n=0; oe2_n=0; #1; if (y !== ~8'h5A) errors++;
        oe1_n=1; oe2_n=1; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x340: %0d errors", errors);
        $display("PASS: tb_ttl_74x340");
        $finish;
    end
endmodule
