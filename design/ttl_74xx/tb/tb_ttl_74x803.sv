`timescale 1ns/1ps
module tb_ttl_74x803;
    logic clk;
    logic [3:0] d, q;
    ttl_74x803 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0;
        for (int v = 0; v < 16; v++) begin
            d = v[3:0]; clk = 0; #1; clk = 1; #1;
            if (q !== v[3:0]) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x803: %0d errors", errors);
        $display("PASS: tb_ttl_74x803");
        $finish;
    end
endmodule
