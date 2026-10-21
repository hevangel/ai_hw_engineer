`timescale 1ns/1ps
module tb_ttl_74x1011;
    logic [2:0] a, b, c, y;
    ttl_74x1011 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int av = 0; av < 8; av++) for (int bv = 0; bv < 8; bv++) for (int cv = 0; cv < 8; cv++) begin
            a = av[2:0]; b = bv[2:0]; c = cv[2:0]; #1;
            if (y !== (a & b & c)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1011: %0d errors", errors);
        $display("PASS: tb_ttl_74x1011");
        $finish;
    end
endmodule
