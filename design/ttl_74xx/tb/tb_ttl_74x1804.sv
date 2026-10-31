`timescale 1ns/1ps
module tb_ttl_74x1804;
    logic [5:0] a, b, y;
    ttl_74x1804 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int av = 0; av < 64; av++) for (int bv = 0; bv < 64; bv++) begin
            a = av[5:0]; b = bv[5:0]; #1;
            if (y !== ~(a & b)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1804: %0d errors", errors);
        $display("PASS: tb_ttl_74x1804");
        $finish;
    end
endmodule
