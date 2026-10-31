`timescale 1ns/1ps
module tb_ttl_74x1241;
    logic [7:0] a, y;
    logic oe1_n, oe2;
    ttl_74x1241 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2 = 1;
        for (int v = 0; v < 256; v++) begin
            a = v[7:0]; #1;
            if (y !== v[7:0]) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1241: %0d errors", errors);
        $display("PASS: tb_ttl_74x1241");
        $finish;
    end
endmodule
