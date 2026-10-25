`timescale 1ns/1ps
module tb_ttl_74x1002;
    logic [3:0] a, b, y;
    ttl_74x1002 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int av = 0; av < 16; av++) for (int bv = 0; bv < 16; bv++) begin
            a = av[3:0]; b = bv[3:0]; #1;
            if (y !== ~(a | b)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1002: %0d errors", errors);
        $display("PASS: tb_ttl_74x1002");
        $finish;
    end
endmodule
