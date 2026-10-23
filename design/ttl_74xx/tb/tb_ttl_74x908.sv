`timescale 1ns/1ps
module tb_ttl_74x908;
    logic [1:0] a, b, y;
    ttl_74x908 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int av = 0; av < 4; av++) begin
            for (int bv = 0; bv < 4; bv++) begin
                a = av[1:0]; b = bv[1:0]; #1;
                if (y !== ~(a & b)) errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x908: %0d errors", errors);
        $display("PASS: tb_ttl_74x908");
        $finish;
    end
endmodule
