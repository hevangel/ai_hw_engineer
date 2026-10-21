`timescale 1ns/1ps
module tb_ttl_74x162244;
    logic [15:0] a, y;
    logic oe1_n, oe2_n;
    ttl_74x162244 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a = 16'hC3A5; #1;
        if (y !== 16'hC3A5) errors++;
        oe1_n = 1; oe2_n = 1; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162244: %0d errors", errors);
        $display("PASS: tb_ttl_74x162244");
        $finish;
    end
endmodule
